import SwiftUI
import SwiftData
import StoreKit
import UIKit

/// The one call site of the App Store review request, and how save paths reach it.
///
/// A save path only says "an entry was saved" through `\.reviewPrompt`. Where
/// that ends up depends on where the view is standing:
///
/// - **On a tab** (the environment `ReviewPromptHost` installs on `MainTabView`):
///   nothing is on top of the screen, so the policy is asked immediately.
/// - **Inside an `entrySheet`**: the save is only noted. The request waits for
///   the sheet's `onDismiss`, so the system prompt never lands on a form that
///   is animating away. A sheet inside a sheet (the Dashboard's quick sheets
///   host whole tab screens, which present their own add sheets) defers to the
///   OUTERMOST one, so the prompt waits until the parent is back on a tab.
///
/// Nothing but a save can set the pending flag, which is what keeps the
/// prompt out of launch, tab switches and Cancel. Onboarding sits outside
/// `MainTabView` and so only ever sees `.inert`.
///
/// The members are internal rather than private so the routing is unit-tested
/// (`ReviewPromptTriggerTests`) without a view hierarchy.
struct ReviewPromptTrigger {
    let note: @MainActor () -> Void
    let flush: @MainActor () -> Void
    let isDeferred: Bool
    /// Where a save is reported to analytics (`first_entry`). Every save path
    /// already calls `entrySaved` once per finished record, so this is the
    /// app's one choke point for it; injected so tests never reach the shared
    /// facade. A sheet's deferred trigger keeps it; `.inert` drops it.
    var logged: @MainActor (AnalyticsEvent.EntryKind) -> Void = { _ in }

    @MainActor func entrySaved(_ kind: AnalyticsEvent.EntryKind) {
        logged(kind)
        note()
        if !isDeferred { flush() }
    }

    @MainActor func sheetDismissed() {
        if !isDeferred { flush() }
    }

    /// What a sheet's content receives: it keeps the ability to note a save
    /// and loses the ability to ask.
    var deferred: ReviewPromptTrigger {
        ReviewPromptTrigger(note: note, flush: {}, isDeferred: true, logged: logged)
    }

    static var inert: ReviewPromptTrigger {
        ReviewPromptTrigger(note: {}, flush: {}, isDeferred: true)
    }

    /// The trigger `MainTabView` installs. `request` is the environment's
    /// `requestReview`, injected so tests can count calls; `analytics` so they
    /// can hand in an isolated facade.
    @MainActor
    static func live(service: ReviewPromptService,
                     context: ModelContext,
                     analytics: Analytics,
                     transactionFailedThisSession: @escaping @MainActor () -> Bool,
                     request: @escaping @MainActor () -> Void) -> ReviewPromptTrigger {
        ReviewPromptTrigger(
            note: { service.noteEntrySaved() },
            flush: {
                // The routing's promise, checked where it is kept: an ask only
                // ever happens with nothing presented over the tabs. Debug
                // builds only — `assert` compiles out of Release.
                assert(!isAnythingPresented, "review prompt asked with a sheet still up")
                if service.consumePendingSave(
                    in: context,
                    transactionFailedThisSession: transactionFailedThisSession()) {
                    request()
                }
            },
            isDeferred: false,
            logged: { analytics.noteEntrySaved($0) }
        )
    }

    /// Whether the app's own window has a view controller presented over its
    /// root — which is what a SwiftUI sheet is underneath.
    ///
    /// Only the scene's KEY window, and only if it is a visible, normal-level
    /// one: StoreKit's rating sheet lives in a window of its own that can
    /// linger after "Not Now", and counting it would crash a dev build on
    /// the next save with nothing of ours on screen.
    @MainActor
    private static var isAnythingPresented: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .filter { !$0.isHidden && $0.windowLevel == .normal }
            .contains { $0.rootViewController?.presentedViewController != nil }
    }
}

private struct ReviewPromptTriggerKey: EnvironmentKey {
    // Computed rather than stored: the closures are not Sendable, and a stored
    // static default would have to be.
    static var defaultValue: ReviewPromptTrigger { .inert }
}

extension EnvironmentValues {
    var reviewPrompt: ReviewPromptTrigger {
        get { self[ReviewPromptTriggerKey.self] }
        set { self[ReviewPromptTriggerKey.self] = newValue }
    }
}

/// Installed once, on `MainTabView`.
private struct ReviewPromptHost: ViewModifier {
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var store

    func body(content: Content) -> some View {
        content.environment(\.reviewPrompt, .live(
            service: .shared,
            context: modelContext,
            analytics: .shared,
            transactionFailedThisSession: { store.transactionFailedThisSession },
            request: { requestReview() }
        ))
    }
}

private struct EntrySheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let sheetContent: () -> SheetContent
    @Environment(\.reviewPrompt) private var outer

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: { outer.sheetDismissed() }) {
            sheetContent().environment(\.reviewPrompt, outer.deferred)
        }
    }
}

private struct EntryItemSheet<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let sheetContent: (Item) -> SheetContent
    @Environment(\.reviewPrompt) private var outer

    func body(content: Content) -> some View {
        content.sheet(item: $item, onDismiss: { outer.sheetDismissed() }) { item in
            sheetContent(item).environment(\.reviewPrompt, outer.deferred)
        }
    }
}

extension View {
    func reviewPromptHost() -> some View { modifier(ReviewPromptHost()) }

    /// `.sheet` for any sheet in which an entry can be saved. Use it for those
    /// and only those — a paywall or an editor presented this way would do no
    /// harm, but it would read as a place where entries are logged.
    func entrySheet<Content: View>(isPresented: Binding<Bool>,
                                   @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(EntrySheet(isPresented: isPresented, sheetContent: content))
    }

    func entrySheet<Item: Identifiable, Content: View>(item: Binding<Item?>,
                                                       @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        modifier(EntryItemSheet(item: item, sheetContent: content))
    }
}
