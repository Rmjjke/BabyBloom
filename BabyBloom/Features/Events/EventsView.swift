import SwiftUI
import SwiftData

struct EventsView: View {
    @Query(sort: \CustomEvent.time, order: .reverse) private var events: [CustomEvent]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {
                    quickAddSection
                        .padding(.horizontal, BBTheme.Spacing.md)

                    historySection
                        .padding(.horizontal, BBTheme.Spacing.md)
                }
                .padding(.bottom, BBTheme.Spacing.xl)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("nav.events".l)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(BBTheme.Colors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddEventSheet()
        }
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.quick_input")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BBTheme.Spacing.md) {
                ForEach([CustomEvent.EventType.bath, .walk, .medication, .mood], id: \.self) { type in
                    Button {
                        quickAdd(type)
                    } label: {
                        VStack(spacing: BBTheme.Spacing.sm) {
                            Image(systemName: type.icon)
                                .font(.system(size: 26))
                                .foregroundStyle(Color(hex: type.colorHex))
                            Text(type.displayName.l)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(BBTheme.Spacing.md)
                        .background(Color(hex: type.colorHex).opacity(0.1))
                        .cornerRadius(BBTheme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                                .stroke(Color(hex: type.colorHex).opacity(0.4), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(BBScaleButtonStyle())
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.history")
            if events.isEmpty {
                EmptyStateView(
                    icon: "star.fill",
                    color: BBTheme.Colors.events,
                    title: "empty.no_records",
                    subtitle: "empty.events_hint"
                )
            } else {
                VStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(events.prefix(20)) { event in
                        SwipeToDeleteRow(onDelete: { delete(event) }) {
                            BBEventRow(
                                icon: event.type.icon,
                                iconColor: Color(hex: event.type.colorHex),
                                title: event.type.displayName.l,
                                subtitle: event.notes ?? (event.mood?.displayName.l ?? ""),
                                time: event.time.formatted(.dateTime.hour().minute()),
                                trailing: event.time.formatted(.dateTime.day().month())
                            )
                        }
                    }
                }
            }
        }
    }

    private func quickAdd(_ type: CustomEvent.EventType) {
        let event = CustomEvent(time: Date(), type: type)
        modelContext.insert(event)
        try? modelContext.save()
    }

    private func delete(_ event: CustomEvent) {
        modelContext.delete(event)
        try? modelContext.save()
    }
}

// MARK: - Add Event Sheet
struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedType: CustomEvent.EventType = .bath
    @State private var notes = ""
    @State private var time = Date()
    @State private var selectedMood: CustomEvent.MoodLevel = .calm
    @State private var medicationName = ""
    @State private var medicationDose = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {
                    // Type grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: BBTheme.Spacing.sm) {
                        ForEach(CustomEvent.EventType.allCases, id: \.self) { type in
                            Button { selectedType = type } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: type.icon).font(.system(size: 22))
                                        .foregroundStyle(selectedType == type ? .white : Color(hex: type.colorHex))
                                    Text(type.displayName.l).font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(selectedType == type ? .white : BBTheme.Colors.textPrimary)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, BBTheme.Spacing.md)
                                .background(selectedType == type ? Color(hex: type.colorHex) : BBTheme.Colors.surface)
                                .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)
                            }
                            .buttonStyle(BBScaleButtonStyle())
                        }
                    }

                    // Mood selector
                    if selectedType == .mood {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            Text("form.mood".l).font(.system(size: 16, weight: .semibold, design: .rounded))
                            HStack(spacing: BBTheme.Spacing.sm) {
                                ForEach(CustomEvent.MoodLevel.allCases, id: \.self) { mood in
                                    Button { selectedMood = mood } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: mood.icon).font(.system(size: 24))
                                                .foregroundStyle(selectedMood == mood ? .white : BBTheme.Colors.accent)
                                            Text(mood.displayName.l).font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(selectedMood == mood ? .white : BBTheme.Colors.textPrimary)
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(selectedMood == mood ? BBTheme.Colors.accent : BBTheme.Colors.surface)
                                        .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)
                                    }
                                    .buttonStyle(BBScaleButtonStyle())
                                }
                            }
                        }
                    }

                    // Medication fields
                    if selectedType == .medication {
                        VStack(spacing: BBTheme.Spacing.sm) {
                            TextField("form.medication_name".l, text: $medicationName)
                                .padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                                .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)
                            TextField("form.dose".l, text: $medicationDose)
                                .padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                                .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)
                        }
                    }

                    // Notes
                    TextField("form.notes".l, text: $notes, axis: .vertical)
                        .lineLimit(3).padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)

                    // Time
                    DatePicker("form.time".l, selection: $time, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact).tint(BBTheme.Colors.primary)
                        .padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)

                    BBPrimaryButton("button.save".l, icon: "checkmark") { save() }
                }
                .padding(BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("sheet.new_event".l)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }.foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
        }
    }

    private func save() {
        let event = CustomEvent(time: time, type: selectedType)
        if selectedType == .mood { event.mood = selectedMood }
        if selectedType == .medication {
            event.medicationName = medicationName.isEmpty ? nil : medicationName
            event.medicationDose = medicationDose.isEmpty ? nil : medicationDose
        }
        event.notes = notes.isEmpty ? nil : notes
        modelContext.insert(event)
        try? modelContext.save()
        dismiss()
    }
}
