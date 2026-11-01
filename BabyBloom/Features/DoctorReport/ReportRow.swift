import SwiftUI

// MARK: - Row

/// «label: value» as ONE Text (label callout, value metricSmall, both
/// textPrimary), so VoiceOver reads it as a sentence and the line wraps as text.
/// At accessibility sizes it stacks label over value, as the weekly card does.
struct ReportRow: View {
    let label: String
    let value: String
    /// A secondary tail on the same line, «· 28 Oct» (caption, textSecondary).
    let suffix: String?
    /// What a translator put after the `%@`; empty in every current language.
    private let tail: String

    @Environment(\.dynamicTypeSize) private var typeSize

    /// `format` is a localized string with one `%@` for the value; it is split
    /// there, so the word order stays the translator's. A `%d` key works too.
    init(format: String, value: String, suffix: String? = nil) {
        let parts = format.replacingOccurrences(of: "%d", with: "%@").components(separatedBy: "%@")
        label = parts.first ?? ""
        tail = parts.dropFirst().joined()
        self.value = value
        self.suffix = suffix
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    BBTheme.Typography.callout(label.trimmingCharacters(in: .whitespaces))
                    valueText
                }
            } else {
                BBTheme.Typography.callout(label) + valueText
            }
        }
        .foregroundStyle(BBTheme.Colors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var valueText: Text {
        var text = BBTheme.Typography.metricSmall(value)
        if !tail.isEmpty { text = text + BBTheme.Typography.callout(tail) }
        if let suffix {
            text = text + BBTheme.Typography.caption(ReportFormat.joiner + suffix)
                .foregroundStyle(BBTheme.Colors.textSecondary)
        }
        return text
    }
}

// MARK: - Header

/// A card's header: a decorative glyph in the category tint and the title.
/// The glyph is hidden because the title already names the section.
struct ReportCardHeader: View {
    let icon: String
    let tint: Color
    let title: String

    @ScaledMetric(relativeTo: .callout) private var glyph: CGFloat = 15

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: glyph))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            BBTheme.Typography.title3(title)
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

// MARK: - Shared pieces

/// A caption line, the report's secondary text.
struct ReportCaption: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        BBTheme.Typography.caption(text)
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// «Days with entries: N of M» and the empty line, shared by the three period cards.
struct ReportDaysLine: View {
    let days: DoctorReportSummary.Days
    let isShort: Bool

    var body: some View {
        // Short periods print raw counts and no days line (R3.3).
        if days.showsLine && !isShort {
            ReportCaption(String(format: "report.days_logged_fmt".l, days.withEntries, days.counted))
        }
    }
}

struct ReportEmptyLine: View {
    let format: String
    let periodStart: Date

    var body: some View {
        BBTheme.Typography.callout(String(format: format.l, periodStart.appDayMonth))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Number + unit formats. Every unit is glued to its number with a
/// no-break space (DECISIONS 2026-10-30), so a line never starts with «kg».
enum ReportFormat {
    static let nbsp = "\u{00A0}"
    /// «·» glued to the item before it: a wrapped list breaks AFTER the dot,
    /// never inside «Breast 120 · Formula».
    static let listSeparator = "\u{00A0}· "
    static var joiner: String { listSeparator }

    static func kg(_ value: Double) -> String { "\(value.appDecimal(2))\(nbsp)\("unit.kg".l)" }
    static func cm(_ value: Double) -> String { "\(value.appDecimal(1))\(nbsp)\("unit.cm".l)" }
    static func ml(_ value: Double) -> String { "\(value.appDecimal(0))\(nbsp)\("unit.ml".l)" }

    /// «+640 g», signed, with the unit attached.
    static func grams(_ grams: Int) -> String {
        "\(WeeklySummary.signed(grams))\(nbsp)\("unit.g".l)"
    }

    /// `WeeklyFormat.duration` with its internal spaces made unbreakable:
    /// «5h 10min» must not split across lines.
    static func duration(_ seconds: TimeInterval) -> String {
        WeeklyFormat.duration(seconds).replacingOccurrences(of: " ", with: nbsp)
    }

    /// «Breast 120», the name and its count held together.
    static func countItem(name: String, count: Int) -> String {
        String(format: "report.type_count_fmt".l, name, count)
            .replacingOccurrences(of: " ", with: nbsp)
    }

    static func countList(_ items: [String]) -> String { items.joined(separator: listSeparator) }
}
