import SwiftUI
import UIKit

/// A medication's reminder switch with the lines under it: when the one
/// pending notification fires, the iOS-off line with its way to Settings, and
/// the footer saying it is this device's and comes at night too. Drawn like
/// the Live Activity switch: while iOS has notifications off, the switch
/// shows off and cannot be turned on here.
struct MedicationReminderCard: View {
    @Binding var isOn: Bool
    /// When the pending notification fires; nil when none is pending.
    let fireDate: Date?
    let now: Date
    @State private var permission = NotificationPermission.shared
    /// The Open Settings chevron grows with its text.
    @ScaledMetric(relativeTo: .footnote) private var chevronSize: CGFloat = 13

    var body: some View {
        let denied = permission.state == .denied
        VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
            // A closure, not `set: turn`: the method reference crashed the
            // compiler (Swift 6, Xcode 26.2) emitting its isolation thunk.
            Toggle(isOn: Binding(get: { isOn && !denied }, set: { turn($0) })) {
                Label {
                    BBTheme.Typography.callout("medication.reminder_switch".l)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(BBTheme.Colors.primary)
                }
            }
            .tint(BBTheme.Colors.primary)
            .frame(minHeight: 44)
            .disabled(denied)
            .accessibilityIdentifier("medication.reminder")
            if denied {
                line("medication.reminder_off_in_settings".l)
                Button(action: openSettings) {
                    HStack(spacing: BBTheme.Spacing.xs) {
                        Text("medication.open_settings".l)
                            .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: chevronSize, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(BBTheme.Colors.primary)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("medication.open_settings")
            } else if isOn, let fireDate {
                // The one fact here that changes, so a size above the footer.
                BBTheme.Typography.callout(String(format: "medication.reminder_at_fmt".l,
                                                  MedicationFormat.when(fireDate, now: now)))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("medication.reminder_at")
            }
            line("medication.reminder_footer".l)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await permission.refresh() }
    }

    /// The first turn-on asks iOS once, through the app's one ask. A refusal
    /// leaves the switch off, and the iOS-off line takes its place.
    private func turn(_ on: Bool) {
        guard on, permission.state == .notAsked else {
            isOn = on
            return
        }
        let binding = $isOn
        NotificationManager.shared.requestPermission { granted in
            if granted { binding.wrappedValue = true }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: .regular, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The detail's reminder card. The switch is stored on this device under the
/// medication's id and takes effect at once.
struct MedicationReminderSection: View {
    let medicine: Medicine
    let now: Date
    @AppStorage private var isOn: Bool

    init(medicine: Medicine, now: Date) {
        self.medicine = medicine
        self.now = now
        _isOn = AppStorage(wrappedValue: false, MedicationReminderPlan.switchKey(for: medicine.id))
    }

    var body: some View {
        MedicationReminderCard(
            isOn: $isOn,
            fireDate: MedicationReminderPlan.fireDate(isOn: isOn, isEnded: medicine.isEnded,
                                                      schedule: medicine.schedule(now: now)),
            now: now)
            .bbCard()
            .onChange(of: isOn) { MedicationReminderSync.shared.reconcile() }
    }
}
