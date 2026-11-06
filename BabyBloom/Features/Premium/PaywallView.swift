import SwiftUI

// MARK: - Paywall View

struct PaywallView: View {
    /// Required, with no default: every presentation site has to say where the
    /// paywall was opened from, or the conversion funnel loses its first step.
    let source: AnalyticsEvent.PaywallSource

    @Environment(SubscriptionManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showRestoreAlert = false
    /// Set when `paywall_shown` goes out — only once this screen is actually
    /// SELLING: the settings row opens it for subscribers too, and they see
    /// the active badge, not an offer.
    @State private var shownAt: Date?
    @State private var closeReported = false
    @State private var planPicker = PlanPickerState()

    /// Selling, and with something to sell: the pinned buy button shows only
    /// then. Subscribers get the active badge; a failed load gets the retry card.
    private var isSelling: Bool {
        store.hasResolvedEntitlements && !store.isPremium && !planPicker.loadFailed(in: store)
    }

    var body: some View {
        // The offer scrolls, the buy button does not (NotificationsPage's
        // arrangement): at AX2 the plans alone reach the fold.
        VStack(spacing: 0) {
            scrollContent
            if isSelling {
                PlanPickerCTA(state: planPicker)
            }
        }
        .background(BBTheme.Colors.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { closeButton }
        .navigationTitle("settings.premium".l)
        .navigationBarTitleDisplayMode(.inline)
        .alert("premium.restore_title".l, isPresented: $showRestoreAlert) {
            Button("button.close".l, role: .cancel) { store.clearRestoreState() }
        } message: {
            Text(store.restoreState == .success
                 ? "premium.restore_success".l
                 : "premium.restore_nothing".l)
        }
        .onChange(of: store.restoreState) { _, new in
            showRestoreAlert = new != nil
        }
        .task {
            await store.refreshEntitlements()
        }
        .onAppear {
            // A save earlier in the same quick sheet is no longer a moment of
            // success once an upsell has been put in front of the parent.
            ReviewPromptService.shared.discardPendingSave()
            reportShownIfSelling()
        }
        .onChange(of: store.hasResolvedEntitlements) { _, _ in reportShownIfSelling() }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── Hero ────────────────────────────────────────────────
                // Shared with onboarding's paywall.
                PremiumHero()

                VStack(spacing: BBTheme.Spacing.lg) {

                    // Sell, or say it is already bought — but only once
                    // StoreKit has actually answered. Before that, `isPremium`
                    // is false because nothing has asked, and an entitled user
                    // opening Settings would be shown the selling half and
                    // could tap the CTA straight into "You are currently
                    // subscribed". Unlike the onboarding host this screen
                    // advances nowhere; it just waits.
                    if store.hasResolvedEntitlements {
                        if store.isPremium {
                            activeBadge
                        } else {
                            PlanPickerSection(state: planPicker)
                        }
                    } else {
                        ProgressView()
                            .padding(.vertical, BBTheme.Spacing.xl)
                    }

                    // Features — shared with onboarding's paywall.
                    PremiumFeatureList()

                    Spacer(minLength: BBTheme.Spacing.xl)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.top, BBTheme.Spacing.lg)
            }
        }
    }

    // MARK: - Close Button (modal dismissal)

    private var closeButton: some View {
        Button {
            // Once, and only for a paywall that was reported shown: a double
            // tap lands twice before the sheet is gone.
            if let shownAt, !closeReported {
                closeReported = true
                Analytics.shared.track(.paywallClosedX(since: shownAt))
            }
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: 44, height: 44)          // ≥44pt tap zone
                .contentShape(Rectangle())
        }
        .accessibilityLabel("button.close".l)
        .padding(.trailing, BBTheme.Spacing.sm)
        .padding(.top, BBTheme.Spacing.sm)
    }

    private func reportShownIfSelling() {
        guard shownAt == nil, store.hasResolvedEntitlements, !store.isPremium else { return }
        shownAt = Date()
        Analytics.shared.track(.paywallShown(source))
    }

    // MARK: - Active Badge

    private var activeBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26))
                .foregroundStyle(BBTheme.Colors.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("premium.active_status".l)
                    .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Text("premium.active_desc".l)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.primary.opacity(0.08))
        .cornerRadius(BBTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: BBTheme.Radius.lg)
                .stroke(BBTheme.Colors.primary.opacity(0.25), lineWidth: 1.5)
        )
    }
}

// MARK: - Feature List

/// The feature card of both paywalls, the in-app one (for subscribers too) and
/// onboarding's. One list for the two: they are the same offer seen at two
/// moments, and a line present in one and missing from the other is a
/// discrepancy a buyer can catch.
///
/// One shape for every row, as in the Nutrition card: rows of one shape read as
/// a list, and a mix of the two does not. The texts stand beside their icons
/// while every word of every row fits there, wrapping between words; otherwise,
/// and at every accessibility size, each text goes under its icon and check.
struct PremiumFeatureList: View {
    /// `onboarding.premium.f4` («Несколько профилей детей») is deliberately
    /// absent: the app has one baby and no way to add a second, so the line
    /// sold something that does not exist. Numbering is left with the gap
    /// rather than resequenced — renaming f5 to f4 would silently change what
    /// every translation of those two keys says.
    static let features: [(icon: String, key: String)] = [
        ("infinity",                  "onboarding.premium.f1"),
        ("star.fill",                 "onboarding.premium.f2"),
        ("square.and.arrow.up.fill",  "onboarding.premium.f3"),
        ("chart.bar.fill",            "onboarding.premium.f5"),
    ]

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize >= .accessibility1 {
                rows(.stacked)
            } else {
                ViewThatFits(in: .horizontal) {
                    rows(.beside)
                    rows(.stacked)
                }
            }
        }
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }

    /// A stack's ideal width is its widest row's, so the beside form fits only
    /// where every row does.
    func rows(_ shape: PremiumFeatureRow.Shape) -> some View {
        let features = Self.features
        return VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { i, feat in
                PremiumFeatureRow(icon: feat.icon, text: feat.key.l, shape: shape)

                if i < features.count - 1 {
                    Divider().padding(.horizontal, BBTheme.Spacing.md)
                }
            }
        }
    }
}

// MARK: - Feature Row

/// A Text only breaks inside a word when the word alone is wider than its
/// space, and beside a 34pt icon, a checkmark and the padding a long Russian
/// word («Неограниченная») was exactly that at the accessibility sizes, and on
/// a 320-pt screen from xLarge. `PremiumFeatureList` picks the shape, one for
/// all its rows.
struct PremiumFeatureRow: View {
    enum Shape { case beside, stacked }

    let icon: String
    let text: String
    let shape: Shape

    private var iconBadge: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(BBTheme.Colors.primary)
            .frame(width: 34, height: 34)
            .background(BBTheme.Colors.primary.opacity(0.1))
            .cornerRadius(9)
    }

    private var check: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(BBTheme.Colors.success)
    }

    /// Its ideal width is its widest word, the width the list's `ViewThatFits`
    /// compares.
    var besideLabel: some View {
        styled(WordWrappingText(text: text))
    }

    private func styled(_ label: some View) -> some View {
        label
            .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        Group {
            switch shape {
            case .beside:
                HStack(spacing: BBTheme.Spacing.md) {
                    iconBadge
                    besideLabel
                    Spacer()
                    check
                }
            case .stacked:
                VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                    HStack {
                        iconBadge
                        Spacer()
                        check
                    }
                    styled(Text(text))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, BBTheme.Spacing.md)
        // One VoiceOver stop with the feature's words only: the bare symbols
        // would be read by their SF names.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
