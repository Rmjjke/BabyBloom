import XCTest
import SwiftUI
@testable import BabyBloom

/// Growth's weight chart as VoiceOver finds it: one element per weighing that
/// reads its date and weight in the app's words, and nothing else in the plot.
@MainActor
final class WeightChartVoiceOverTests: XCTestCase {

    private let birth = Date(timeIntervalSince1970: 1_700_000_000)
    private let accessibility = HostedAccessibility()

    override func tearDown() {
        accessibility.close()
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    private func at(_ ageDays: Int, _ kg: Double, hour: Int = 10) -> WeightMeasurement {
        let day = Calendar.current.date(byAdding: .day, value: ageDays, to: birth)!
        return WeightMeasurement(date: day.addingTimeInterval(TimeInterval(hour * 3600)), weightKg: kg)
    }

    /// The Growth screen's three shapes where weighings stand closer than an
    /// element is wide: the storefront curve, the newborn weeks, two on a day.
    private var courses: [(name: String, weighings: [WeightMeasurement])] {
        [
            ("showcase", SeedScenario.showcaseWeighings.map { at($0.ageDays, $0.weightKg) }),
            ("newborn", [at(0, 3.50), at(3, 3.25), at(7, 3.30), at(14, 3.60), at(20, 3.95)]),
            ("same-day", [at(0, 3.50, hour: 8), at(0, 5.00, hour: 13), at(2, 3.45)]),
        ]
    }

    func testEveryWeighingReadsItsDateAndWeightAndNothingElseSpeaks() throws {
        for language in [SupportedLanguage.en, .ru] {
            LocalizationManager.shared.setLanguage(language)
            for course in courses {
                let root = try accessibility.host(chart(course.weighings).frame(width: 370),
                                                  size: CGSize(width: 402, height: 420))
                let found = accessibility.elements(root)
                print("WEIGHT_READOUT \(language) \(course.name):\n  " + found.map(\.description).joined(separator: "\n  "))
                for descriptor in accessibility.chartDescriptors(root) {
                    print("WEIGHT_AUDIO_GRAPH \(language) \(course.name): \(descriptor.readout)")
                }

                let expected = course.weighings.map { (label: caption($0), value: weight($0)) }
                let points = found.filter { element in expected.contains { $0.label == element.label } }
                XCTAssertEqual(points.map(\.label), expected.map(\.label),
                               "\(language) \(course.name): one element per weighing, oldest first")
                XCTAssertEqual(points.map(\.value), expected.map(\.value), "\(language) \(course.name)")

                let readout = "\(weight(course.weighings.last!)), \(caption(course.weighings.last!))"
                let stray = found.filter { element in
                    !expected.contains { $0.label == element.label }
                        && element.label != readout
                        && element.label != "chart.who_corridor".l
                }
                XCTAssertEqual(stray.map(\.description), [], "\(language) \(course.name): nothing else speaks")
            }
        }
    }

    /// Onboarding's growth page draws its corridor as plain paths, hidden from
    /// VoiceOver: nothing on the page reads a date range.
    func testTheOnboardingShowcaseSketchSaysNothing() throws {
        for language in [SupportedLanguage.en, .ru] {
            LocalizationManager.shared.setLanguage(language)
            for birthWeightKg in [nil, 3.4] as [Double?] {
                let page = GrowthShowcasePage(babyName: "Mia", birthDate: birth, gender: .female,
                                              birthWeightKg: birthWeightKg, gestationalWeeks: nil, onContinue: {})
                let root = try accessibility.host(page, size: CGSize(width: 402, height: 874))
                let found = accessibility.elements(root)
                let tag = birthWeightKg == nil ? "invitation" : "reading"
                print("SHOWCASE_READOUT \(language) \(tag):\n  " + found.map(\.description).joined(separator: "\n  "))
                XCTAssertEqual(accessibility.chartDescriptors(root).count, 0, "\(language) \(tag): no chart summary")
                // Swift Charts' merged element reads «13 Nov 2023 at 00 to 20
                // Nov 2023 at 00» with the value «3,4 to 3,18, 2 values».
                let ranged = found.filter {
                    $0.label.range(of: #"\d{4} at \d{2} to "#, options: .regularExpression) != nil
                        || $0.value.hasSuffix(" values")
                }
                XCTAssertEqual(ranged.map(\.description), [], "\(language) \(tag): no date range")
            }
        }
    }

    // MARK: The chart and its words

    private func chart(_ weighings: [WeightMeasurement]) -> WeightChartView {
        WeightChartView(measurements: weighings, correctedBirthDate: birth, birthDate: birth, isMale: false)
    }

    /// The readout's second line, as the chart writes it.
    private func caption(_ weighing: WeightMeasurement) -> String {
        let ageDays = Calendar.current.dateComponents([.day], from: birth, to: weighing.date).day ?? 0
        let age = ageDays <= 0 ? "chart.at_birth".l : Baby.describeAge(from: birth, to: weighing.date)
        return weighing.date.appDayMonth + ReportFormat.listSeparator + age
    }

    private func weight(_ weighing: WeightMeasurement) -> String {
        "\(weighing.weightKg.appDecimal(2))\u{00A0}\("unit.kg".l)"
    }
}
