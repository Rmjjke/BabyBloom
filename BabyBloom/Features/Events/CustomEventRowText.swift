import Foundation

extension CustomEvent {
    /// A medication shows its name and dose as typed; every other type its
    /// note, or its mood. One home for the Events history, Home and Recent
    /// activity, so the three rows cannot read differently.
    var rowText: (title: String, subtitle: String) {
        let typeWord = type.displayName.l
        guard type == .medication else {
            return (typeWord, notes ?? (mood?.displayName.l ?? ""))
        }
        return MedicationFormat.eventRow(typeWord: typeWord, isDose: isDose,
                                         name: medicationName,
                                         dose: medicationDose, note: notes)
    }
}
