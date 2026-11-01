import Foundation

/// Where the pediatrician report's period starts, and which questions are open.
/// Pure: the report screen, the PDF and the tests read the same answers.
enum DoctorPeriod {

    /// The visit the period starts at: the latest DATE, and on the same date
    /// the one logged last (Manager's decision). A visit logged late with an
    /// earlier date therefore never moves the period (R4.3).
    static func latestVisit(_ visits: [DoctorVisit]) -> DoctorVisit? {
        visits.max { a, b in
            a.date != b.date ? a.date < b.date : a.createdAt < b.createdAt
        }
    }

    /// 00:00 of the latest visit's day, so entries made on the visit day belong
    /// to the new period (plan v2 decision 6); the start of the birth day when
    /// there is no visit.
    static func start(visits: [DoctorVisit], birthDate: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: latestVisit(visits)?.date ?? birthDate)
    }

    /// Open questions, oldest first, so they are asked in the order they came up.
    static func openQuestions(_ questions: [DoctorQuestion]) -> [DoctorQuestion] {
        questions
            .filter(\.isOpen)
            .sorted { $0.createdAt < $1.createdAt }
    }
}
