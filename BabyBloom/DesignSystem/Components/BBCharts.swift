import SwiftUI

// MARK: - History Filter

enum HistoryFilter: String, CaseIterable {
    case day   = "filter.day"
    case week  = "filter.week"
    case month = "filter.month"
    case year  = "filter.year"

    /// The earliest date that falls within this filter period (start of that day).
    func startDate() -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        switch self {
        case .day:   return today
        case .week:  return cal.date(byAdding: .day,   value: -6,  to: today)!
        case .month: return cal.date(byAdding: .month, value: -1,  to: today)!
        case .year:  return cal.date(byAdding: .year,  value: -1,  to: today)!
        }
    }
}

// MARK: - Filter Picker

struct BBHistoryFilterPicker: View {
    @Binding var selected: HistoryFilter

    var body: some View {
        HStack(spacing: 2) {
            ForEach(HistoryFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selected = filter
                    }
                } label: {
                    Text(filter.rawValue.l)
                        .font(.system(size: 13, weight: selected == filter ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(selected == filter ? .white : BBTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            Group {
                                if selected == filter {
                                    RoundedRectangle(cornerRadius: 10).fill(BBTheme.Colors.primary)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(BBTheme.Colors.primary.opacity(0.08))
        .cornerRadius(14)
    }
}

// MARK: - Weekly Bar Chart

struct BBWeeklyBarChart: View {

    struct Day: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double

        var isToday: Bool { Calendar.current.isDateInToday(date) }

        /// 2-letter weekday abbreviation in the current app language.
        var shortLabel: String {
            let lang = LocalizationManager.shared.currentLanguage
            let f = DateFormatter()
            f.locale = Locale(identifier: lang == "ru" ? "ru_RU" : "en_US")
            f.dateFormat = "EEE"
            return String(f.string(from: date).prefix(2)).capitalized
        }
    }

    let days: [Day]       // 7 items, oldest first → today last
    let color: Color
    var formatValue: (Double) -> String = { v in
        v == floor(v) ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private var maxVal: Double { max(days.map(\.value).max() ?? 1, 0.001) }
    private let barMaxH: CGFloat = 80

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(days) { day in
                VStack(spacing: 3) {
                    // Value label above bar
                    Group {
                        if day.value > 0 {
                            Text(formatValue(day.value))
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(day.isToday ? color : BBTheme.Colors.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 12)

                    // Bar (grows from bottom)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(day.isToday
                                  ? LinearGradient(colors: [color, color.opacity(0.7)],
                                                   startPoint: .top, endPoint: .bottom)
                                  : LinearGradient(colors: [color.opacity(0.4), color.opacity(0.25)],
                                                   startPoint: .top, endPoint: .bottom))
                            .frame(height: max(3, CGFloat(day.value / maxVal) * barMaxH))
                    }
                    .frame(height: barMaxH)

                    // Day label
                    Text(day.shortLabel)
                        .font(.system(size: 10, weight: day.isToday ? .bold : .medium, design: .rounded))
                        .foregroundStyle(day.isToday ? color : BBTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }

    /// Build 7 Day structs: [6 days ago … today].
    static func lastSevenDays(valueFor: (Date) -> Double) -> [Day] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return (0..<7).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -(6 - offset), to: startOfToday)!
            return Day(date: date, value: valueFor(date))
        }
    }
}

// MARK: - Delete History Button

struct BBDeleteHistoryButton: View {
    let onDelete: () -> Void
    @State private var showConfirm = false

    var body: some View {
        Button {
            showConfirm = true
        } label: {
            Label("button.delete_history".l, systemImage: "trash")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(BBTheme.Spacing.md)
                .background(Color.red.opacity(0.06))
                .cornerRadius(BBTheme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        }
        .alert("button.delete_history".l, isPresented: $showConfirm) {
            Button("button.delete".l, role: .destructive) { onDelete() }
            Button("button.cancel".l, role: .cancel) {}
        } message: {
            Text("confirm.delete_message".l)
        }
    }
}
