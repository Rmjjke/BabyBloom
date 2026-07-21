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

    private struct Day: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double

        var isToday: Bool { Calendar.current.isDateInToday(date) }
        var isFuture: Bool { date > Calendar.current.startOfDay(for: Date()) }

        var shortLabel: String {
            let lang = LocalizationManager.shared.currentLanguage
            let f = DateFormatter()
            f.locale = Locale(identifier: lang == "ru" ? "ru_RU" : "en_US")
            f.dateFormat = "EEE"
            return String(f.string(from: date).prefix(2)).capitalized
        }

        var dayNumber: String {
            "\(Calendar.current.component(.day, from: date))"
        }
    }

    let valueFor: (Date) -> Double
    let color: Color
    var formatValue: (Double) -> String = { v in
        v == floor(v) ? "\(Int(v))" : String(format: "%.1f", v)
    }

    @State private var weekOffset = 0   // 0 = current week, -1 = last week, …

    private var canGoForward: Bool { weekOffset < 0 }
    private let barMaxH: CGFloat = 80

    private func mondayOf(_ date: Date) -> Date {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)   // 1=Sun … 7=Sat
        let daysFromMonday = (weekday - 2 + 7) % 7          // Mon=0 … Sun=6
        return cal.date(byAdding: .day, value: -daysFromMonday, to: cal.startOfDay(for: date))!
    }

    private var weekDays: [Date] {
        let cal = Calendar.current
        let monday = mondayOf(Date())
        let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: monday)!
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: weekStart)! }
    }

    private var days: [Day] {
        weekDays.map { Day(date: $0, value: valueFor($0)) }
    }

    private var maxVal: Double { max(days.map(\.value).max() ?? 1, 0.001) }

    private var monthTitle: String {
        let first = weekDays.first!
        let last  = weekDays.last!
        let cal   = Calendar.current
        let lang  = LocalizationManager.shared.currentLanguage
        let f     = DateFormatter()
        f.locale  = Locale(identifier: lang == "ru" ? "ru_RU" : "en_US")
        if cal.component(.month, from: first) == cal.component(.month, from: last) {
            f.dateFormat = "LLLL yyyy"
            return f.string(from: first).capitalized
        } else {
            f.dateFormat = "LLL"
            let m1 = f.string(from: first).capitalized
            let m2 = f.string(from: last).capitalized
            f.dateFormat = "yyyy"
            return "\(m1) – \(m2) \(f.string(from: last))"
        }
    }

    var body: some View {
        VStack(spacing: BBTheme.Spacing.sm) {

            // Month header + navigation
            HStack(spacing: BBTheme.Spacing.sm) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { weekOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BBTheme.Colors.primary)
                        .frame(width: 28, height: 28)
                        .background(BBTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(8)
                        .frame(width: 44, height: 44)      // ≥44pt tap zone (visual stays 28)
                        .contentShape(Rectangle())
                }

                Spacer()

                Text(monthTitle)
                    .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                    .id(monthTitle)   // triggers transition on week change

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { weekOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(canGoForward ? BBTheme.Colors.primary : BBTheme.Colors.textSecondary.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(canGoForward ? BBTheme.Colors.primary.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                        .frame(width: 44, height: 44)      // ≥44pt tap zone (visual stays 28)
                        .contentShape(Rectangle())
                }
                .disabled(!canGoForward)
            }

            // Bars
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
                                .fill(day.isFuture
                                      ? LinearGradient(colors: [color.opacity(0.08), color.opacity(0.05)],
                                                       startPoint: .top, endPoint: .bottom)
                                      : day.isToday
                                          ? LinearGradient(colors: [color, color.opacity(0.7)],
                                                           startPoint: .top, endPoint: .bottom)
                                          : LinearGradient(colors: [color.opacity(0.4), color.opacity(0.25)],
                                                           startPoint: .top, endPoint: .bottom))
                                .frame(height: max(day.isFuture ? 2 : 3,
                                                   CGFloat(day.value / maxVal) * barMaxH))
                        }
                        .frame(height: barMaxH)

                        // Day labels: weekday + day number
                        VStack(spacing: 1) {
                            Text(day.shortLabel)
                                .font(.system(size: 9, weight: day.isToday ? .bold : .medium, design: .rounded))
                                .foregroundStyle(day.isToday ? color : BBTheme.Colors.textSecondary)
                            Text(day.dayNumber)
                                .font(.system(size: 11, weight: day.isToday ? .bold : .regular, design: .rounded))
                                .foregroundStyle(day.isToday ? color : BBTheme.Colors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .id(weekOffset)   // re-render bars when week changes
            .transition(.opacity)
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < 0 {
                        withAnimation(.easeInOut(duration: 0.2)) { weekOffset -= 1 }
                    } else if value.translation.width > 0, canGoForward {
                        withAnimation(.easeInOut(duration: 0.2)) { weekOffset += 1 }
                    }
                }
        )
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
                .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
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
