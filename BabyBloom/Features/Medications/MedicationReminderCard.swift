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
            reminderSwitch(Binding(get: { isOn && !denied }, set: { turn($0) }), denied: denied)
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

    /// The switch beside its title while every word of the title keeps whole
    /// there, else under the title at its x, as a Settings switch row stands
    /// (uk «Сповіщати» missed beside it on a 320-pt screen at AX2); with no
    /// room for a word beside the bell either, the bell goes above. One
    /// switch either way, with the same identifier and the title for
    /// VoiceOver.
    private func reminderSwitch(_ binding: Binding<Bool>, denied: Bool) -> some View {
        let title = "medication.reminder_switch".l
        return ViewThatFits(in: .horizontal) {
            ProbedIdealWidth {
                Toggle(isOn: binding) {
                    Label {
                        reminderTitle(title)
                    } icon: {
                        bell
                    }
                }
                .tint(BBTheme.Colors.primary)
                .frame(minHeight: 44)
                .disabled(denied)
                .accessibilityIdentifier("medication.reminder")
                // The same row one word a line: its ideal width is the
                // narrowest the drawn row keeps every word whole at.
                Toggle(isOn: .constant(false)) {
                    Label {
                        reminderTitle(title.oneWordALine)
                    } icon: {
                        bell
                    }
                }
                .hidden()
                .accessibilityHidden(true)
            }
            ProbedIdealWidth {
                Label {
                    switchUnder(title, binding, denied: denied)
                } icon: {
                    bell
                }
                Label {
                    reminderTitle(title.oneWordALine)
                } icon: {
                    bell
                }
                .hidden()
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
                bell
                switchUnder(title, binding, denied: denied)
            }
        }
        .wordFitTypesetting()
    }

    private func switchUnder(_ title: String, _ binding: Binding<Bool>, denied: Bool) -> some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            // The switch carries the title for VoiceOver.
            reminderTitle(title)
                .accessibilityHidden(true)
            Toggle(isOn: binding) {
                Text(title)
            }
            .labelsHidden()
            .fixedSize()
            .tint(BBTheme.Colors.primary)
            .disabled(denied)
            .accessibilityIdentifier("medication.reminder")
        }
    }

    private func reminderTitle(_ text: String) -> some View {
        BBTheme.Typography.callout(text)
            .foregroundStyle(BBTheme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var bell: some View {
        Image(systemName: "bell.fill")
            .foregroundStyle(BBTheme.Colors.primary)
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
