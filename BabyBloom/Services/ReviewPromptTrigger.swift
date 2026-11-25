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
    /// can hand in an isolated facade; `isAnythingPresented` and `retry` so
    /// they can play a sheet that is still going down.
    @MainActor
    static func live(service: ReviewPromptService,
                     context: ModelContext,
                     analytics: Analytics,
                     transactionFailedThisSession: @escaping @MainActor () -> Bool,
                     isAnythingPresented: @escaping @MainActor () -> Bool = { Self.isAnythingPresented },
                     retry: @escaping @MainActor (@escaping @MainActor () -> Void) -> Void = Self.retrySoon,
                     request: @escaping @MainActor () -> Void) -> ReviewPromptTrigger {
        // The routing's promise, kept here in every build: an ask only ever
        // happens with nothing presented over the tabs. A swipe-down runs the
        // sheet's onDismiss when the drag BEGINS, with the sheet still up, so
        // the ask waits for it to finish going down. A drag let go of keeps
        // the sheet: the tries run out, the save stays pending, and the
        // sheet's real dismissal asks about it later.
        func askOnceNothingIsPresented(triesLeft: Int) {
            guard service.hasPendingSave else { return }
            guard !isAnythingPresented() else {
                if triesLeft > 0 { retry { askOnceNothingIsPresented(triesLeft: triesLeft - 1) } }
                return
            }
            if service.consumePendingSave(
                in: context,
                transactionFailedThisSession: transactionFailedThisSession()) {
                request()
            }
        }
        return ReviewPromptTrigger(
            note: { service.noteEntrySaved() },
            flush: { askOnceNothingIsPresented(triesLeft: Self.presentedTries) },
            isDeferred: false,
            logged: { analytics.noteEntrySaved($0) }
        )
    }

    /// 100 × 0.1 s: a sheet's dismissal animation is well under a second, but
    /// a finger may rest on a half-dragged sheet before letting it go down,
    /// and a look every 0.1 s costs nothing. A drag let go of past this keeps
    /// the save pending for the sheet's next dismissal.
    static let presentedTries = 100

    @MainActor
    static func retrySoon(_ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            work()
        }
    }

    /// Whether the app's own window has a view controller presented over its
    /// root — which is what a SwiftUI sheet is underneath.
    ///
    /// Only the scene's KEY window, and only if it is a visible, normal-level
    /// one: StoreKit's rating sheet lives in a window of its own that can
    /// linger after "Not Now", and counting it would crash a dev build on
    /// the next save with nothing of ours on screen.
    ///
    /// An app on its way to the background counts as covered too: an ask
    /// there would spend the version's one prompt on a screen nobody sees.
    /// Only foreground-active scenes count, so a sheet left open in another
    /// iPad window does not hold the ask back.
    @MainActor
    static var isAnythingPresented: Bool {
        guard UIApplication.shared.applicationState == .active else { return true }
        return UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
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
    let onDismiss: (() -> Void)?
    let sheetContent: () -> SheetContent
    @Environment(\.reviewPrompt) private var outer

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: {
            outer.sheetDismissed()
            onDismiss?()
        }) {
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
    ///
    /// `onDismiss` runs after the review prompt has heard the dismissal.
    func entrySheet<Content: View>(isPresented: Binding<Bool>,
                                   onDismiss: (() -> Void)? = nil,
                                   @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(EntrySheet(isPresented: isPresented, onDismiss: onDismiss, sheetContent: content))
    }

    func entrySheet<Item: Identifiable, Content: View>(item: Binding<Item?>,
                                                       @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        modifier(EntryItemSheet(item: item, sheetContent: content))
    }
}
