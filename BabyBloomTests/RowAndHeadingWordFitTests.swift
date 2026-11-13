import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import BabyBloom

/// Every switch beside a text, the weekly chart's month title and the section
/// headings keep each word whole, in every shipped language, at a 320 and a
/// 375-pt width, with Bold Text off and on, at the content size the simulator
/// runs (the gate runs the class at Large, AX1 and AX2).
///
/// The views are hosted as the app hosts them, with its language environment
/// and typesetting, and judged on what they drew: text recognition reads a
/// render, so a word cut with a hyphen or without fails alike.
@MainActor
final class RowAndHeadingWordFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()

    override func tearDown() {
        accessibility.close()
        FitLanguage.restore()
        super.tearDown()
    }

    func testRowsHeadingsAndChartTitlesKeepWordsWholeAt320() throws {
        try checkScenes(width: 320)
    }

    func testRowsHeadingsAndChartTitlesKeepWordsWholeAt375() throws {
        try checkScenes(width: 375)
    }

    /// The three Settings rows draw no hyphen in Ukrainian across the widths a
    /// phone gives them, and their German hints stay whole at 300 pt.
    func testSwitchRowsDrawNoHyphenInsideAWord() throws {
        var misses: [String] = []
        let uk = FitLanguage.real(.uk)
        uk.apply()
        let widths = Array(stride(from: CGFloat(236), through: 300, by: 4))
        misses += try judge(uk, columns: widths.map { settingsRows(width: $0, language: uk) }, bold: false)

        let de = FitLanguage.real(.de)
        de.apply()
        misses += try judge(de, columns: [settingsRows(width: 300, language: de)], bold: false)
        XCTAssert(misses.isEmpty, misses.joined(separator: "\n"))
    }

    /// Korean's own typesetting breaks a word between two syllables; the three
    /// Settings rows break only between words, from 150 to 300 pt.
    func testKoreanSwitchRowsBreakOnlyBetweenWords() throws {
        let ko = FitLanguage.real(.ko)
        ko.apply()
        let widths = Array(stride(from: CGFloat(150), through: 300, by: 10))
        let misses = try judge(ko, columns: widths.map { settingsRows(width: $0, language: ko) }, bold: false)
        XCTAssert(misses.isEmpty, misses.joined(separator: "\n"))
    }

    // MARK: Number and counter

    func testCounterGlueIsIdempotent() {
        for text in ["2026年11月", "11月3日 – 9日", "11월 2일", "24時間", "3 kg", "", "Marraskuu 2026"] {
            XCTAssertEqual(text.gluingNumbersToCounters.gluingNumbersToCounters, text.gluingNumbersToCounters, text)
        }
    }

    func testReportRangesAndChartTitlesKeepNumbersWithCounters() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 12))!
        for language in [SupportedLanguage.ja, .ko, .zhHant] {
            FitLanguage.real(language).apply()
            let locale = language.locale
            var built: [String] = []
            for month in 1...12 {
                let first = calendar.date(from: DateComponents(year: 2026, month: month, day: 3, hour: 12))!
                let last = calendar.date(byAdding: .day, value: 6, to: first)!
                let across = calendar.date(byAdding: .day, value: 26, to: first)!
                built.append(ReportFormat.dayRange(first, last, now: now))
                built.append(ReportFormat.dayRange(first, across, now: now))
                built.append(ReportFormat.dayRange(calendar.date(byAdding: .year, value: -1, to: first)!, last, now: now))
                built.append(LocaleDates.monthTitle(first, first, locale: locale).gluingNumbersToCounters)
                built.append(LocaleDates.monthTitle(first, across, locale: locale).gluingNumbersToCounters)
            }
            for text in built {
                XCTAssertNil(text.range(of: #"\d[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}]"#, options: .regularExpression),
                             "\(language.rawValue): «\(text)» lets a line end between a number and its counter")
            }
        }
    }

    // MARK: Scenes

    private struct Column {
        let width: CGFloat
        let view: AnyView
        /// Each judged text, or the texts one of which the view draws.
        let texts: [[String]]
        /// The weekly charts' titles, in the order the charts stand.
        var chartTitles: [String] = []
    }

    private static let side: CGFloat = 2700
    private static let height: CGFloat = side

    private func checkScenes(width: CGFloat) throws {
        guard #available(iOS 18.0, *) else { throw XCTSkip("iOS 18") }
        var misses: [String] = []
        for language in SupportedLanguage.available.map(FitLanguage.real) {
            language.apply()
            for bold in [false, true] {
                // The test method's own pool drains only when it returns: each
                // round's renders, windows and store would pile up to gigabytes.
                try autoreleasepool {
                    misses += try judge(language, columns: try sceneColumns(width: width, language: language), bold: bold)
                }
            }
        }
        XCTAssert(misses.isEmpty, "\(misses.count) misses:\n" + misses.joined(separator: "\n"))
    }

    /// Hosts the columns side by side in scenes a hosted layer can draw: one
    /// over 8192 px a side at the screen's 3x draws all black.
    private func judge(_ language: FitLanguage, columns: [Column], bold: Bool) throws -> [String] {
        var groups: [[Column]] = [[]]
        for column in columns {
            if groups[groups.count - 1].reduce(column.width, { $0 + $1.width }) > Self.side { groups.append([]) }
            groups[groups.count - 1].append(column)
        }
        var misses: [String] = []
        for group in groups {
            try autoreleasepool {
                defer { accessibility.close() }
                misses += try judgeScene(language, columns: group, bold: bold)
            }
        }
        return misses
    }

    /// Reads each column of one scene and judges its texts; the chart columns
    /// also have their header read from the accessibility tree.
    private func judgeScene(_ language: FitLanguage, columns: [Column], bold: Bool) throws -> [String] {
        let total = columns.reduce(0) { $0 + $1.width }
        let scene = HStack(alignment: .top, spacing: 0) {
            ForEach(columns.indices, id: \.self) { index in
                columns[index].view
                    .frame(width: columns[index].width, height: Self.height, alignment: .top)
                    .clipped()
            }
        }
        .environment(\.horizontalSizeClass, .compact)
        .ignoresSafeArea()
        // The onboarding pages fade their text in on appear; on a loaded
        // simulator the read can come mid-fade and see blank or faint lines.
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        let root = try accessibility.host(scene, size: CGSize(width: total, height: Self.height), bold: bold)
        RunLoop.main.run(until: Date().addingTimeInterval(1))

        let scale: CGFloat = 2
        let image = try XCTUnwrap(DrawnTextReader.render(root, scale: scale))
        let tag = "\(language) \(bold ? "bold" : "regular")"
        var misses: [String] = []
        var x: CGFloat = 0
        let elements = columns.contains { !$0.chartTitles.isEmpty } ? accessibility.elements(root, automation: true) : []
        let rects = columns.indices.map { index in
            CGRect(x: columns[..<index].reduce(0) { $0 + $1.width }, y: 0, width: columns[index].width, height: Self.height)
        }
        let columnLines = try DrawnTextReader.lines(in: image, rects: rects, scale: scale, languages: Self.recognition(language.base))
        for (column, lines) in zip(columns, columnLines) {
            defer { x += column.width }
            var judge = DrawnWordJudge(lines: lines, script: Self.isCJK(language.base) ? .cjk : .words)
            var columnMisses: [String] = []
            // Longest first: a short text (one month's title) would otherwise
            // take the lines of a longer one that holds it (a two-month week).
            let ordered = column.texts.sorted { lhs, rhs in
                lhs.map { DrawnWordJudge.skeleton($0).count }.max() ?? 0 > rhs.map { DrawnWordJudge.skeleton($0).count }.max() ?? 0
            }
            for alternatives in ordered {
                var firstMiss: String?
                var drawn = false
                for text in alternatives {
                    var trial = judge
                    guard let verdict = trial.judge(text) else { judge = trial; drawn = true; break }
                    firstMiss = firstMiss ?? verdict
                }
                if !drawn, let firstMiss { columnMisses.append(firstMiss) }
            }
            if !columnMisses.isEmpty {
                misses += columnMisses.map { "\(tag) \(Int(column.width)) pt: \($0)" }
                misses.append("  drawn: " + lines.map(\.text).joined(separator: " ⏎ "))
            }
            if !column.chartTitles.isEmpty {
                misses += chartHeaderMisses(elements.filter { $0.frame.midX >= x && $0.frame.midX < x + column.width },
                                            titles: column.chartTitles).map { "\(tag) \(Int(column.width)) pt: \($0)" }
            }
        }
        return misses
    }

    /// Each week button keeps a 44-pt tap zone, and every chart of the column
    /// sets its title the same way, beside the buttons or above them.
    private func chartHeaderMisses(_ elements: [HostedAccessibility.Element], titles: [String]) -> [String] {
        var misses: [String] = []
        let previous = elements.filter { $0.label == "chart.previous_week".l }.sorted { $0.frame.minY < $1.frame.minY }
        let next = elements.filter { $0.label == "chart.next_week".l }
        if previous.count != titles.count || next.count != titles.count {
            return ["\(previous.count) and \(next.count) week buttons for \(titles.count) charts"]
        }
        for button in previous + next where button.frame.width < 43.5 || button.frame.height < 43.5 {
            misses.append("week button «\(button.label)» is \(Int(button.frame.width))×\(Int(button.frame.height)) pt")
        }
        let plain = Set(titles.map { $0.replacingOccurrences(of: "\u{2060}", with: "") })
        let titleElements = elements.filter { plain.contains($0.label.replacingOccurrences(of: "\u{2060}", with: "")) }
        var layouts: [String: [String]] = [:]
        for button in previous {
            guard let title = titleElements.filter({ $0.frame.minY <= button.frame.midY }).max(by: { $0.frame.minY < $1.frame.minY }) else {
                misses.append("no month title above the week button at y \(Int(button.frame.minY))")
                continue
            }
            let layout = abs(title.frame.midY - button.frame.midY) < 22 ? "beside" : "above"
            layouts[layout, default: []].append(title.label)
        }
        if layouts.count > 1 {
            misses.append("the month title stands beside the buttons for \(layouts["beside"]!) and above them for \(layouts["above"]!)")
        }
        return misses
    }

    private func sceneColumns(width w: CGFloat, language: FitLanguage) throws -> [Column] {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        container.mainContext.insert(Baby(name: "Mia", birthDate: Date(), gender: .female, feedingType: .breast))
        try container.mainContext.save()
        let subscriptions = SubscriptionManager()
        func screen(_ view: some View) -> AnyView {
            AnyView(view.environment(subscriptions).modelContainer(container).appLanguageEnvironment(language.base))
        }
        func stack(@ViewBuilder _ content: () -> some View) -> AnyView {
            screen(VStack(alignment: .leading, spacing: BBTheme.Spacing.md, content: content)
                .padding(BBTheme.Spacing.md)
                .fixedSize(horizontal: false, vertical: true))
        }

        let settings = Column(width: w, view: screen(NavigationStack { ProfileView() }), texts: [
            ["settings.notify_weekly".l], ["settings.notify_weekly_hint".l],
            ["settings.live_activity".l], ["settings.live_activity_hint".l, "settings.live_activity_off_in_ios".l],
            ["settings.analytics".l], ["settings.analytics_hint".l],
        ])
        let switches = Column(width: w, view: stack {
            MedicationReminderCard(isOn: .constant(true), fireDate: nil, now: Date()).medicationField()
            measureToggle("form.height_cm".l)
            measureToggle("form.head_cm".l)
        }, texts: [["medication.reminder_switch".l], ["form.height_cm".l], ["form.head_cm".l],
                   ["form.head_optional_hint".l], ["form.head_optional_hint".l]])
        let feeding = Column(width: w, view: screen(AddFeedingSheet()),
                             texts: [["form.start_timer".l], ["form.timer_hint".l]])
        let export = Column(width: w, view: screen(NavigationStack { ExportView() }),
                            texts: ["export.cat.feeding", "export.cat.sleep", "export.cat.diapers", "export.cat.growth", "export.cat.events"].map { [$0.l] })
        let reportCards: [(String, Color, String)] = [
            ("scalemass.fill", BBTheme.Colors.growth, "export.cat.growth"),
            ("drop.fill", BBTheme.Colors.diaper, "export.cat.diapers"),
            ("pills.fill", BBTheme.Colors.accent, "medication.report_title"),
            ("heart.fill", BBTheme.Colors.feeding, "export.cat.feeding"),
            ("moon.fill", BBTheme.Colors.sleep, "export.cat.sleep"),
        ]
        let headings = Column(width: w, view: stack {
            PercentileOutOfRangeCard()
            InsightCard(title: "section.who_percentiles".l, info: .control(action: {})) {
                Text(verbatim: " ")
            }
            ForEach(reportCards, id: \.2) { icon, tint, key in
                ReportCardHeader(icon: icon, tint: tint, title: key.l).bbCard()
            }
        }, texts: [["section.who_percentiles".l], ["section.who_percentiles".l]] + reportCards.map { [$0.2.l] })

        let weeks = chartWeeks()
        let charts = stride(from: 0, to: weeks.count, by: 5).map { first -> Column in
            let part = Array(weeks[first..<min(first + 5, weeks.count)])
            return Column(width: w, view: stack {
                ForEach(part, id: \.offset) { week in
                    BBWeeklyBarChart(valueFor: { _ in 1 }, color: BBTheme.Colors.sleep, startingWeekOffset: week.offset)
                }
            }, texts: part.map { [$0.title] }, chartTitles: part.map(\.title))
        }

        let name = "Mia"
        let onboarding = [
            Column(width: w, view: screen(GrowthShowcasePage(
                babyName: name, birthDate: Date().addingTimeInterval(-10 * 86_400), gender: .female,
                birthWeightKg: 3.45, gestationalWeeks: nil, onContinue: {})),
                   texts: [[String(format: "onboarding.showcase.title".l, name)], ["section.who_percentiles".l]]),
            Column(width: w, view: screen(GeneratingPage(babyName: name, birthDate: Date(), onDone: {})),
                   texts: [[String(format: "onboarding.gen.title_named".l, name)]]),
            Column(width: w, view: screen(NotificationsPage(babyName: name, onContinue: {})),
                   texts: [[String(format: "onboarding.notify.title".l, name)]]),
            Column(width: w, view: screen(WidgetShowcasePage(babyName: name, onContinue: {})),
                   texts: [["onboarding.widget.title".l]]),
        ]
        return [settings, switches, feeding, export, headings] + charts + onboarding
    }

    private func settingsRows(width: CGFloat, language: FitLanguage) -> Column {
        let rows = [("settings.notify_weekly", "settings.notify_weekly_hint", "bell.badge"),
                    ("settings.live_activity", "settings.live_activity_hint", "lock.iphone"),
                    ("settings.analytics", "settings.analytics_hint", "chart.bar")]
        let view = VStack(alignment: .leading, spacing: BBTheme.Spacing.lg) {
            ForEach(rows, id: \.0) { title, hint, icon in
                SettingsSwitchRow(title: title.l, hint: hint.l, systemImage: icon, isOn: .constant(true))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .appLanguageEnvironment(language.base)
        return Column(width: width, view: AnyView(view), texts: rows.flatMap { [[$0.0.l], [$0.1.l]] })
    }

    private func measureToggle(_ title: String) -> some View {
        BBOptionalMeasureToggle(title: title, hint: "form.head_optional_hint".l, isOn: .constant(false),
                                value: .constant(50), range: 25...130, step: 0.5, display: Units.cm("50"),
                                minLabel: Units.cm("25"), maxLabel: Units.cm("130"), color: BBTheme.Colors.primary)
    }

    /// One week inside each of the last twelve months, the week across into
    /// this month and the week across into January, as offsets from this week
    /// with the titles the chart sets for them.
    private func chartWeeks() -> [(offset: Int, title: String)] {
        let language = LocalizationManager.shared.language
        let calendar = language.calendar
        let thisMonday = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        let monthStart = calendar.dateInterval(of: .month, for: Date())!.start
        var mondays: [Date] = []
        for back in 0..<12 {
            let first = calendar.date(byAdding: .month, value: -back, to: monthStart)!
            // The first Monday falls on day 1 to 7, so its whole week is inside the month.
            mondays.append(calendar.nextDate(after: calendar.date(byAdding: .day, value: -1, to: first)!,
                                             matching: DateComponents(weekday: 2), matchingPolicy: .nextTime)!)
        }
        let january = calendar.date(from: DateComponents(year: calendar.component(.year, from: Date()), month: 1, day: 1))!
        for first in [monthStart, january] {
            let monday = calendar.dateInterval(of: .weekOfYear, for: first)!.start
            if monday != first { mondays.append(monday) }
        }
        return mondays.map { monday in
            let offset = calendar.dateComponents([.weekOfYear], from: thisMonday, to: monday).weekOfYear!
            let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
            return (offset, LocaleDates.monthTitle(monday, sunday, locale: language.locale).gluingNumbersToCounters)
        }
    }

    // MARK: Recognition

    private static func isCJK(_ language: SupportedLanguage) -> Bool {
        [SupportedLanguage.ja, .zhHant].contains(language)
    }

    /// The recogniser's languages, the text's own first. Finnish has no model
    /// of its own: Swedish reads its letters, ä and ö included.
    private static func recognition(_ language: SupportedLanguage) -> [String] {
        switch language.rawValue {
        case "en": ["en-US"]
        case "ru": ["ru-RU", "en-US"]
        case "uk": ["uk-UA", "en-US"]
        case "es": ["es-ES", "en-US"]
        case "fr": ["fr-FR", "en-US"]
        case "de": ["de-DE", "en-US"]
        case "sv", "fi": ["sv-SE", "en-US"]
        case "nb": ["nb-NO", "en-US"]
        case "da": ["da-DK", "en-US"]
        case "pt-BR", "pt-PT": ["pt-BR", "en-US"]
        case "ja": ["ja-JP", "en-US"]
        case "ko": ["ko-KR", "en-US"]
        case "zh-Hant": ["zh-Hant", "en-US"]
        default: ["en-US"]
        }
    }
}
