import SwiftUI

// MARK: - Birth + gender (page 3 of 9)

struct BirthPage: View {
    @Binding var birthDate: Date
    @Binding var gender: Baby.Gender
    /// Prematurity lives here because it is a fact about the birth. Birth
    /// weight used to sit beside it, as an optional toggle, back when the next
    /// page asked for the weight TODAY; that page now asks for the measurements
    /// at birth, so the same number is collected once, there.
    @Binding var gestationalWeeks: Double
    @Binding var wasBornEarly: Bool
    let onBack: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            backButton(action: onBack)

            ScrollView(showsIndicators: false) {
                VStack(spacing: BBTheme.Spacing.xl) {
                    onboardingHeroIcon("calendar", color: BBTheme.Colors.primary)
                        .padding(.top, BBTheme.Spacing.md)

                    VStack(spacing: BBTheme.Spacing.sm) {
                        BBSteppedTitle("onboarding.birth_title".l)
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("onboarding.birth_hint".l)
                            .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .regular, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Gender: one column at accessibility sizes. On a 320-pt
                    // screen half the row keeps «Мальчик» 13.5 pt at AX2 and
                    // 4.6 with Bold Text, under the 8-pt spare; below them two
                    // hold, with 38 pt to spare at xxxLarge in Bold.
                    let genderColumns = BBTileColumns(large: 2, xLarge: 2, xxLarge: 2, xxxLarge: 2, accessibility: 1)
                    if genderColumns.count(at: dynamicTypeSize) == 1 {
                        VStack(spacing: BBTheme.Spacing.md) {
                            genderTiles
                        }
                    } else {
                        HStack(spacing: BBTheme.Spacing.md) {
                            genderTiles
                        }
                    }

                    // Date picker (compact)
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        BirthCalendar(date: $birthDate)
                    }
                    .padding(BBTheme.Spacing.sm)
                    .background(BBTheme.Colors.surface)
                    .cornerRadius(BBTheme.Radius.lg)
                    .bbShadow(BBTheme.Shadow.card)

                    // Off by default: a parent who does not know the gestational
                    // age must be able to walk past this without a made-up
                    // number being stored — corrected age would then measure a
                    // real baby against fiction.
                    BBOptionalMeasureToggle(
                        title: "form.preterm".l,
                        hint: "form.preterm_hint".l,
                        isOn: $wasBornEarly,
                        value: $gestationalWeeks,
                        range: 22...36, step: 1,
                        display: String(format: "unit.weeks_short_fmt".l, Int(gestationalWeeks)),
                        minLabel: String(format: "unit.weeks_short_fmt".l, 22),
                        maxLabel: String(format: "unit.weeks_short_fmt".l, 36),
                        color: BBTheme.Colors.accent
                    )

                    Spacer(minLength: BBTheme.Spacing.xl)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, 20)
            }
        }
    }

    private var genderTiles: some View {
        ForEach(Baby.Gender.allCases, id: \.self) { g in
            Button {
                withAnimation(.spring(response: 0.3)) { gender = g }
            } label: {
                VStack(spacing: 8) {
                    // The figure grows with its word: it stands over it, not
                    // in a plate.
                    Image(systemName: g == .female ? "figure.stand.dress" : "figure.stand")
                        .font(BBTheme.Typography.scaled(34, relativeTo: .body, weight: .regular, design: .default))
                        .foregroundStyle(gender == g ? BBTheme.Colors.primary : BBTheme.Colors.textSecondary)
                    Text(g.displayName.l)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
                        .foregroundStyle(gender == g ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, BBTheme.Spacing.md)
                .background(gender == g ? BBTheme.Colors.primary.opacity(0.12) : Color.clear).background(BBTheme.Colors.surface)
                .cornerRadius(BBTheme.Radius.md)
                .bbShadow(BBTheme.Shadow.card)
                .bbSelectedBorder(gender == g)
            }
            .buttonStyle(BBScaleButtonStyle())
        }
    }
}

// MARK: - Birth calendar

/// The graphical date picker, its text no larger than its header can hold.
///
/// The system picker grows its header with the text size: the month button
/// from the leading edge, the two arrow buttons from the trailing one, and
/// neither gives way to the other. At AX2 on a 320-pt phone the month's
/// chevron sat 1.5 pt from the previous-month arrow, their hit areas
/// overlapping, and Spanish months touched it at the default size. So the
/// picker takes its own cap: the largest size at which every month title of
/// the app's language leaves the two buttons apart.
struct BirthCalendar: View {
    @Binding var date: Date
    @State private var width: CGFloat?
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.legibilityWeight) private var legibilityWeight

    var body: some View {
        DatePicker("onboarding.birth_label".l,
                   selection: $date,
                   in: ...Date(),
                   displayedComponents: .date)
            .datePickerStyle(.graphical)
            .tint(BBTheme.Colors.primary)
            // The picker fills the width it is offered whatever its text
            // size, so reading its width here never feeds back.
            .dynamicTypeSize(...(width.map { Self.cachedCap(width: $0, locale: locale, calendar: calendar,
                                                            bold: legibilityWeight == .bold) }
                                 ?? .accessibility5))
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
    }

    /// The header at one text size, as UIKit draws it (iOS 26): the title's
    /// point size, each arrow button's width and the title's chevron, with
    /// Bold Text off and on (it draws the title heavy and its glyphs wider).
    struct HeaderMetrics {
        let size: DynamicTypeSize
        let font: CGFloat
        let arrow: CGFloat
        let chevron: CGFloat
        let boldArrow: CGFloat
        let boldChevron: CGFloat
    }

    /// Largest first. UIKit itself draws the picker no larger than
    /// accessibility1 on a phone, so that is the largest size measured; a
    /// wider screen that holds it there keeps the picker at it. The xSmall
    /// row's semibold widths follow its neighbours; the rest are measured.
    static let headerMetrics: [HeaderMetrics] = [
        HeaderMetrics(size: .accessibility1, font: 28, arrow: 51.67, chevron: 17.33, boldArrow: 53, boldChevron: 18),
        HeaderMetrics(size: .xxxLarge, font: 23, arrow: 48, chevron: 14, boldArrow: 49, boldChevron: 15),
        HeaderMetrics(size: .xxLarge, font: 21, arrow: 46.33, chevron: 12.67, boldArrow: 47.67, boldChevron: 14),
        HeaderMetrics(size: .xLarge, font: 19, arrow: 45, chevron: 12, boldArrow: 46, boldChevron: 12.33),
        HeaderMetrics(size: .large, font: 17, arrow: 43.33, chevron: 10.33, boldArrow: 44.33, boldChevron: 11),
        HeaderMetrics(size: .medium, font: 16, arrow: 42.67, chevron: 9.67, boldArrow: 43.33, boldChevron: 10.33),
        HeaderMetrics(size: .small, font: 15, arrow: 41.67, chevron: 9.33, boldArrow: 43, boldChevron: 10),
        HeaderMetrics(size: .xSmall, font: 14, arrow: 41, chevron: 9, boldArrow: 42, boldChevron: 9),
    ]

    /// The least room between the month button and the previous-month
    /// button: the model reads UIKit's frames to within 2 pt.
    static let minimumGap: CGFloat = 2

    /// The room between the month button and the previous-month button in a
    /// picker `width` wide. The month button starts 8 pt in and pads its
    /// title and chevron 4 pt each side and between; the two arrow buttons
    /// end 6 pt past the trailing edge. Under Bold Text UIKit still lays the
    /// title out at its semibold width (and draws it heavy in that frame);
    /// only the arrow and chevron glyphs grow.
    static func headerGap(title: String, width: CGFloat, metrics: HeaderMetrics, bold: Bool = false) -> CGFloat {
        let font = UIFont.systemFont(ofSize: metrics.font, weight: .semibold)
        let text = (title as NSString).size(withAttributes: [.font: font]).width
        let arrow = bold ? metrics.boldArrow : metrics.arrow
        let chevron = bold ? metrics.boldChevron : metrics.chevron
        return width - 14 - 2 * arrow - chevron - text
    }

    /// Every month's title in a year, the month standing alone with its year
    /// as the picker writes it («Сентябрь 2026 г.»), its first letter made
    /// capital: Swedish draws «september 2026», and the capital is the wider
    /// form, the one to fit. UIKit sometimes shortens a long month, but not
    /// every time, so the full form is the one to fit.
    static func monthTitles(locale: Locale, calendar: Calendar, year: Int) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        return (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 15)).map { date in
                let title = formatter.string(from: date)
                return title.prefix(1).uppercased(with: locale) + title.dropFirst()
            }
        }
    }

    /// The largest text size at which every month of this year and the last
    /// keeps the header's buttons apart; the smallest measured when none does.
    static func textSizeCap(width: CGFloat, locale: Locale, calendar: Calendar, bold: Bool = false,
                            now: Date = Date()) -> DynamicTypeSize {
        let year = calendar.component(.year, from: now)
        let titles = monthTitles(locale: locale, calendar: calendar, year: year)
            + monthTitles(locale: locale, calendar: calendar, year: year - 1)
        let fits = headerMetrics.first { metrics in
            titles.allSatisfy { headerGap(title: $0, width: width, metrics: metrics, bold: bold) >= minimumGap }
        }
        return (fits ?? headerMetrics[headerMetrics.count - 1]).size
    }

    /// The cap measures up to 168 titles; every tap on a day redraws the
    /// page, so it is kept per width, language, year and weight.
    @MainActor private static var caps: [String: DynamicTypeSize] = [:]

    @MainActor private static func cachedCap(width: CGFloat, locale: Locale, calendar: Calendar,
                                             bold: Bool) -> DynamicTypeSize {
        let year = calendar.component(.year, from: Date())
        let key = "\(width)|\(locale.identifier)|\(year)|\(bold)"
        if let cap = caps[key] { return cap }
        let cap = textSizeCap(width: width, locale: locale, calendar: calendar, bold: bold)
        caps[key] = cap
        return cap
    }
}
