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
    /// What follows the value in the format — « cm» in `growth.head_fmt`.
    private let tail: String

    @Environment(\.dynamicTypeSize) private var typeSize

    /// `format` is a localized string; it is split at argument `position`
    /// (`FormatSplit`), so the word order stays the translator's even when a
    /// translation reorders the arguments. `others` fill the rest.
    init(format: String, at position: Int = 1, filling others: [any CVarArg] = [],
         value: String, suffix: String? = nil) {
        let split = FormatSplit(format, at: position, value: value, filling: others)
        label = split?.head ?? format
        tail = split?.tail ?? ""
        self.value = value
        self.suffix = suffix
    }

    /// A label that is not a key: a medication's name as typed, never read
    /// as a format.
    init(label: String, value: String, suffix: String? = nil) {
        self.label = label
        self.tail = ""
        self.value = value
        self.suffix = suffix
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
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
///
/// Where a word of the title misses the width beside the glyph, the glyph
/// goes above the title, as a list row's icon does; only a word wider than
/// the whole card sets the title smaller (`BBSteppedText`).
struct ReportCardHeader: View {
    let icon: String
    let tint: Color
    let title: String

    @ScaledMetric(relativeTo: .callout) private var glyph: CGFloat = 15

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                glyphView
                titleView(stepping: false)
            }
            VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
                glyphView
                titleView(stepping: true)
            }
        }
    }

    private var glyphView: some View {
        Image(systemName: icon)
            .font(.system(size: glyph))
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private func titleView(stepping: Bool) -> some View {
        BBSteppedText(title, stepping: stepping)
            .foregroundStyle(BBTheme.Colors.textPrimary)
            .accessibilityAddTraits(.isHeader)
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
    /// The line qualifies an average: under raw counts it would count days
    /// for a figure that is not there.
    let averaged: Bool

    var body: some View {
        if days.showsLine && averaged {
            ReportCaption(String(format: "report.days_logged_fmt".l, days.withEntries, days.counted))
        }
    }
}

struct ReportEmptyLine: View {
    let format: String
    let periodStart: Date

    var body: some View {
        BBTheme.Typography.callout(ReportFormat.sentence(format.l, date: ReportFormat.dayMonth(periodStart)))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
