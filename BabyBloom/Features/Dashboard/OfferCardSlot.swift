import SwiftData
import SwiftUI

/// What Home's offer slot holds and how the card leaves. Home asks it to
/// evaluate when it appears; the slot never inserts a card on its own while
/// Home stays on screen, it only takes one away.
@MainActor
@Observable
final class OfferSlotState {

    /// The card on Home, or nil.
    private(set) var content: OfferContent?
    /// Reduce Motion's close: the card fades in place before it is removed,
    /// so nothing below it slides.
    private(set) var fadingOut = false
    /// The card's own paywall is up: the card stays under it, untouched by
    /// holds and evaluations, and goes when the paywall closes.
    private var paywallOpen = false

    private let service: OfferService
    private let review: ReviewPromptService

    init(service: OfferService = .shared, review: ReviewPromptService = .shared) {
        self.service = service
        self.review = review
    }

    /// Home appeared (tab shown, app brought forward on Home, or the account
    /// resolved during that appear).
    func evaluate(in context: ModelContext, isPremium: Bool, entitlementsResolved: Bool,
                  situation: OfferRule.Situation) {
        guard !paywallOpen else { return }
        // The other direction of one ask per visit: after a rating, no card.
        // It holds like the rule's holds: nothing is spent.
        guard !review.askedThisSession else {
            removeWithoutAnimation()
            return
        }
        let decision = service.evaluate(in: context, isPremium: isPremium,
                                        entitlementsResolved: entitlementsResolved, situation: situation)
        guard let next = decision.content else {
            // A new appear, not a live change: no exit animation to watch.
            removeWithoutAnimation()
            return
        }
        if content != next { removeWithoutAnimation(); content = next }
        // Both are idempotent: a card continuing from an earlier visit is
        // not reported again, and the rating stays off for this process.
        service.recordShown(next)
        review.suppressForSession()
    }

    /// × on the card.
    func close(reduceMotion: Bool) {
        guard let closed = content, !fadingOut else { return }
        service.recordClosed(closed)
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { fadingOut = true }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.2))
                guard let self, self.content == closed else { return }
                self.removeWithoutAnimation()
            }
        } else {
            // The card fades and Home's stack closes the gap in the same curve.
            withAnimation(.easeOut(duration: 0.25)) { content = nil }
        }
    }

    /// A hold came on while the card shows (a sheet, a notification tap, a
    /// dose that turned due). It comes back only at a later appear the rule
    /// allows; the hold itself spends nothing.
    func hold(reduceMotion: Bool) {
        guard content != nil, !paywallOpen else { return }
        if reduceMotion {
            removeWithoutAnimation()
        } else {
            withAnimation(.easeOut(duration: 0.2)) { content = nil }
        }
    }

    /// The card's body: the paywall opens over it.
    func tap() {
        guard let tapped = content else { return }
        service.recordTapped(tapped)
        paywallOpen = true
    }

    /// The paywall opened from the card closed, bought or not.
    func paywallClosed() {
        guard paywallOpen else { return }
        paywallOpen = false
        removeWithoutAnimation()
    }

    private func removeWithoutAnimation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            content = nil
            fadingOut = false
        }
    }
}

/// The offer card in Home's stack, wired to the slot's state.
struct OfferCardSlot: View {
    let state: OfferSlotState
    let model: OfferCardModel
    /// Read once a minute while the card shows: a dose that turns due takes
    /// the card away within a minute, with no notification wiring.
    let medicationDue: () -> Bool
    let onOpen: (OfferContent) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        BBOfferCard(model: model,
                    onOpen: {
                        state.tap()
                        onOpen(model.content)
                    },
                    onClose: { state.close(reduceMotion: reduceMotion) })
            .opacity(state.fadingOut ? 0 : 1)
            // Removal only: the card is decided at appear and has no entrance,
            // so an insertion never animates whatever the transaction says.
            .transition(.asymmetric(insertion: .identity, removal: .opacity))
            .task(id: model.content) {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    if !Task.isCancelled, medicationDue() { state.hold(reduceMotion: reduceMotion) }
                }
            }
    }
}

extension OfferRule.Situation {
    /// The live part of the situation Home builds; the weekly card's
    /// turnover is added at evaluation only, it cannot start mid-visit.
    var holdsLive: Bool { medicationDue || launchedFromNotification || sheetOpen }
}

extension Medicine {
    /// A dose may be taken now on a course Home shows: the parent has a task
    /// on screen, and an offer would compete with it.
    static func doseDueOnHome(_ medicines: [Medicine], now: Date) -> Bool {
        onHome(medicines, now: now).contains { medicine in
            if case .allowed = medicine.status(now: now) { return true }
            return false
        }
    }
}

extension WeeklySummary {
    /// Today the weekly card is new on Home: a summary exists, the parent has
    /// not hidden this week's card, and today is the first day of the
    /// current week (the week turnover).
    static func cardIsNew(_ summary: WeeklySummary?, hiddenWeek: String, now: Date) -> Bool {
        guard let summary, hiddenWeek != WeeklySummaryCard.key(of: summary.week) else { return false }
        return calendar.isDate(now, inSameDayAs: summary.week.end)
    }
}
