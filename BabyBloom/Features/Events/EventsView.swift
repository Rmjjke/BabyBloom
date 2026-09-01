import SwiftUI
import SwiftData

struct EventsView: View {
    @Query(sort: \CustomEvent.time, order: .reverse) private var events: [CustomEvent]
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var store
    @State private var showAddSheet = false
    @State private var showPaywall = false

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
                    Button { addEvent() } label: {
                        // A badge, not a substitution: replacing the plus with
                        // a padlock loses the "this adds something" affordance,
                        // and the gate reads just as clearly beside it.
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(BBTheme.Colors.primary)
                            if !store.isPremium {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(BBTheme.Colors.textSecondary)
                                    .offset(x: 5, y: 3)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddEventSheet()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    /// The single gate for creating an event on this screen. Both creation
    /// paths — the toolbar sheet and the quick-add tiles — go through it, so
    /// the padlock cannot promise a gate that a tile below it walks around.
    private func addEvent(_ type: CustomEvent.EventType? = nil) {
        guard store.isPremium else {
            showPaywall = true
            return
        }
        if let type {
            quickAdd(type)
        } else {
            showAddSheet = true
        }
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.quick_input")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BBTheme.Spacing.md) {
                ForEach([CustomEvent.EventType.bath, .walk, .medication, .mood], id: \.self) { type in
                    Button {
                        addEvent(type)
                    } label: {
                        VStack(spacing: BBTheme.Spacing.sm) {
                            ZStack(alignment: .bottomTrailing) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 26))
                                    .foregroundStyle(Color(hex: type.colorHex))
                                if !store.isPremium {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(BBTheme.Colors.textSecondary)
                                        .offset(x: 8, y: 4)
                                }
                            }
                            Text(type.displayName.l)
                                .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .bbCardTonal(Color(hex: type.colorHex))
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
                                time: event.time.appTimeOfDay,
                                trailing: event.time.appDayMonth
                            )
                        }
                    }
                }
            }
        }
    }

    private func quickAdd(_ type: CustomEvent.EventType) {
        let event = CustomEvent(time: Date(), type: type)
        event.baby = babies.first
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
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @State private var selectedType: CustomEvent.EventType = .bath
    @State private var notes = ""
    @State private var time = Date()
    @State private var selectedMood: CustomEvent.MoodLevel = .calm
    @State private var medicationName = ""
    @State private var medicationDose = ""
    /// Start at `.large` so all fields are visible without a manual drag (brief §2).
    @State private var selectedDetent: PresentationDetent = .large

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
                                        .foregroundStyle(selectedType == type ? BBTheme.Colors.primary : Color(hex: type.colorHex))
                                    Text(type.displayName.l).font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(selectedType == type ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, BBTheme.Spacing.md)
                                .background(selectedType == type ? BBTheme.Colors.primary.opacity(0.12) : BBTheme.Colors.surface)
                                .cornerRadius(BBTheme.Radius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                                        .strokeBorder(selectedType == type ? BBTheme.Colors.primary : Color.clear, lineWidth: 1.5)
                                )
                                .bbShadow(BBTheme.Shadow.card)
                            }
                            .buttonStyle(BBScaleButtonStyle())
                        }
                    }

                    // Mood selector
                    if selectedType == .mood {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            Text("form.mood".l).font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded))
                            HStack(spacing: BBTheme.Spacing.sm) {
                                ForEach(CustomEvent.MoodLevel.allCases, id: \.self) { mood in
                                    Button { selectedMood = mood } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: mood.icon).font(.system(size: 24))
                                                .foregroundStyle(selectedMood == mood ? BBTheme.Colors.primary : BBTheme.Colors.accent)
                                            Text(mood.displayName.l).font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(selectedMood == mood ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(selectedMood == mood ? BBTheme.Colors.primary.opacity(0.12) : BBTheme.Colors.surface)
                                        .cornerRadius(BBTheme.Radius.md)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                                                .strokeBorder(selectedMood == mood ? BBTheme.Colors.primary : Color.clear, lineWidth: 1.5)
                                        )
                                        .bbShadow(BBTheme.Shadow.card)
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
                }
                .padding(BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                BBPrimaryButton("button.save".l, icon: "checkmark") { save() }
                    .padding(.horizontal, BBTheme.Spacing.md)
                    .padding(.top, BBTheme.Spacing.sm)
                    .padding(.bottom, BBTheme.Spacing.xs)
                    .background(BBTheme.Colors.background)
            }
            .navigationTitle("sheet.new_event".l)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }.foregroundStyle(BBTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save".l) { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(BBTheme.Colors.primary)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large], selection: $selectedDetent)
    }

    private func save() {
        let event = CustomEvent(time: time, type: selectedType)
        if selectedType == .mood { event.mood = selectedMood }
        if selectedType == .medication {
            event.medicationName = medicationName.isEmpty ? nil : medicationName
            event.medicationDose = medicationDose.isEmpty ? nil : medicationDose
        }
        event.notes = notes.isEmpty ? nil : notes
        event.baby = babies.first
        modelContext.insert(event)
        try? modelContext.save()
        dismiss()
    }
}
