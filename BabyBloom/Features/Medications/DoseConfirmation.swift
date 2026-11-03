import SwiftUI
import SwiftData
import UIKit

/// The calm confirmation a dose gets when it sits inside the interval of a
/// logged dose, or takes some 24 hours over the maximum. It states the facts
/// and never blocks: Save keeps the dose.
struct DoseConfirmation: Equatable {
    let title: String
    let message: String
}

/// The medication and time an alert asked about. Its Save stores exactly
/// these, and nothing when the choice has changed meanwhile (the medication
/// ended or went on another device), so it never files a dose nobody
/// confirmed.
struct ConfirmedDose: Equatable {
    let medicineID: PersistentIdentifier
    let time: Date
}

extension MedicationFormat {
    /// The words for `check`, or nil when the dose is on time.
    ///
    /// One alert per save. The 24-hour variant shows only when the check says
    /// that, once this dose is saved, the maximum ends later than the
    /// interval. On a tie, and for a dose put before a logged one, the
    /// interval variant.
    ///
    /// The «not before» of the before and 24-hour variants is `nextAfterSave`:
    /// the time the medication's screen shows once this dose is saved. The
    /// time before the save would send a parent who saves anyway and follows
    /// the alert hours early (last dose 08:00, this one 10:00, every 6 h: the
    /// screen then says 16:00, not 14:00).
    static func confirmation(name: String, check: DoseCheck, intervalMinutes: Int,
                             nextAfterSave: Date?, now: Date,
                             calendar: Calendar = .current) -> DoseConfirmation? {
        let interval = duration(minutes: intervalMinutes)
        func at(_ date: Date) -> String { when(date, now: now, calendar: calendar) }
        // The «not before» is each message's last line, in every language (a
        // test pins it). For a dose logged after the fact it can lie in the
        // past, where it would read as advice that has expired, so it goes.
        func message(_ text: String, next: Date) -> String {
            guard next <= now else { return text }
            return text.components(separatedBy: "\n").dropLast().joined(separator: "\n")
        }
        if check.showsDaily, let daily = check.daily {
            // With this dose counted `nextAfterSave` always exists; the
            // window's end only guards a caller that passes none.
            let next = nextAfterSave ?? daily.windowStart.addingTimeInterval(MedicineSchedule.day)
            return DoseConfirmation(
                title: String(format: "medication.alert_max_title_fmt".l, doseCount(daily.count)),
                message: message(String(format: "medication.alert_max_message_fmt".l, name, daily.max, at(next)),
                                 next: next))
        }
        switch check.neighbour {
        case .earlier(let dose, let intervalEnds):
            let next = nextAfterSave ?? intervalEnds
            // "Last dose" only when this dose would be the newest once saved;
            // put between two logged doses, the earlier one is "a logged dose".
            let keys = check.laterDoseLogged
                ? ("medication.alert_between_title_fmt", "medication.alert_between_message_fmt")
                : ("medication.alert_before_title_fmt", "medication.alert_before_message_fmt")
            return DoseConfirmation(
                title: String(format: keys.0.l, interval),
                message: message(String(format: keys.1.l, name, at(dose), at(next)), next: next))
        case .later(let dose):
            return DoseConfirmation(
                title: String(format: "medication.alert_after_title_fmt".l, interval),
                message: String(format: "medication.alert_after_message_fmt".l, name, at(dose), interval))
        case nil:
            return nil
        }
    }
}

extension Medicine {
    /// The confirmation a dose of this medication at `time` needs, or nil.
    ///
    /// None for an ended course: it shows no next time to name. None for an
    /// edited dose saved at `loggedTime`, the time the sheet read when it
    /// opened: the parent changed the dose or the note, and an alert about a
    /// time they did not touch would read as a verdict on the edit. The
    /// sheet's copy, not the live dose, so a move made on another device
    /// meanwhile does not count as the parent's.
    func confirmation(for time: Date, now: Date, editing: CustomEvent? = nil,
                      loggedTime: Date? = nil) -> DoseConfirmation? {
        if isEnded { return nil }
        if let loggedTime, time == loggedTime { return nil }
        let schedule = schedule(now: now, excluding: editing)
        return MedicationFormat.confirmation(name: name, check: schedule.check(time),
                                             intervalMinutes: intervalMinutes,
                                             nextAfterSave: schedule.nextAllowed(adding: time), now: now)
    }
}

extension View {
    /// The confirmation as a system alert, which scales at large text, is read
    /// by VoiceOver and colours nothing. Cancel has the cancel role, the side
    /// that keeps things as they were (iOS 26 draws both buttons alike; the
    /// role carries the meaning), and returns to the sheet with every field
    /// kept. Save has no role: keeping the dose is neither destructive nor wrong.
    func doseConfirmation(_ confirmation: DoseConfirmation?, isPresented: Binding<Bool>,
                          onSave: @escaping () -> Void) -> some View {
        alert(confirmation?.title ?? "", isPresented: isPresented) {
            Button("button.cancel".l, role: .cancel) {}
            Button("button.save".l) { onSave() }
        } message: {
            Text(verbatim: confirmation?.message ?? "")
        }
    }

    /// A field that wraps but stays one paragraph: Return ends editing instead
    /// of starting a line, and a pasted line break becomes a space. A name or
    /// dose with a line break would carry it into every row, the alert and the
    /// export.
    func oneParagraph(_ text: Binding<String>) -> some View {
        onChange(of: text.wrappedValue) { _, new in
            let flat = MedicationFormInput.oneParagraph(new)
            guard flat != new else { return }
            text.wrappedValue = flat
            if new.last?.isNewline == true {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
            }
        }
    }
}
