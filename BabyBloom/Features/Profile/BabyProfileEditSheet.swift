import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Reusable Avatar View

struct BabyAvatarView: View {
    let photoData: Data?
    let gender: Baby.Gender?
    let size: CGFloat

    var body: some View {
        Group {
            if let data = photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [BBTheme.Colors.accent.opacity(0.5), BBTheme.Colors.primary.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "figure.child")
                        .font(.system(size: size * 0.50))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Baby Profile Edit Sheet

struct BabyProfileEditSheet: View {
    // Not `@Bindable`: no control on this sheet binds to the model any more,
    // and the type is what says so — a `$baby.…` binding would be the defect
    // this sheet was fixed for.
    let baby: Baby
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    // Only for the entitlement `NotificationManager` needs in `save()` — this
    // sheet sells nothing.
    @Environment(SubscriptionManager.self) private var store

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showRemovePhotoAlert = false

    // EVERY field on this sheet is edited locally and written back in `save()`,
    // so Cancel discards the lot. The controls used to write to the model as the
    // parent touched them, which made Cancel a lie: half of them — gender,
    // feeding type, the photo — were already committed by the time it was
    // tapped, and the birth date committed on every scroll of the picker.
    //
    // The optional pair below is buffered for a second reason too: the model
    // stores them as optionals ("unknown" is a real answer) while the sliders
    // need concrete values to sit on.
    @State private var editedName: String
    @State private var editedBirthDate: Date
    @State private var editedGender: Baby.Gender
    @State private var editedFeedingType: Baby.FeedingType
    @State private var editedPhotoData: Data?
    @State private var recordsBirthWeight: Bool
    @State private var birthWeightKg: Double
    @State private var wasBornEarly: Bool
    @State private var gestationalWeeks: Double

    init(baby: Baby) {
        self.baby = baby
        _editedName = State(initialValue: baby.name)
        _editedBirthDate = State(initialValue: baby.birthDate)
        _editedGender = State(initialValue: baby.gender)
        _editedFeedingType = State(initialValue: baby.feedingType)
        _editedPhotoData = State(initialValue: baby.photoData)
        _recordsBirthWeight = State(initialValue: baby.birthWeightKg != nil)
        _birthWeightKg = State(initialValue: baby.birthWeightKg ?? 3.4)
        _wasBornEarly = State(initialValue: baby.gestationalWeeks != nil)
        _gestationalWeeks = State(initialValue: Double(baby.gestationalWeeks ?? 34))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {

                    // ── Photo picker ─────────────────────────────────────
                    avatarSection

                    // ── Name ─────────────────────────────────────────────
                    formSection {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            Text("profile.name_label".l)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                            TextField("onboarding.name_placeholder".l, text: $editedName)
                                .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .regular, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                                // Return only dismisses the keyboard — the name
                                // is committed by Save like everything else.
                                .submitLabel(.done)
                        }
                    }

                    // ── Birth date ────────────────────────────────────────
                    formSection {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            Text("profile.birth_date".l)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                            DatePicker("", selection: $editedBirthDate,
                                       in: ...latestSelectableBirthDate,
                                       displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(BBTheme.Colors.primary)
                        }
                    }

                    // ── Birth weight ──────────────────────────────────────
                    formSection {
                        BBOptionalMeasureToggle(
                            title: "form.birth_weight_kg".l,
                            hint: "form.birth_weight_hint".l,
                            isOn: $recordsBirthWeight,
                            value: $birthWeightKg,
                            range: 0.5...6.0, step: 0.05,
                            display: String(format: "%.2f \("unit.kg".l)", birthWeightKg),
                            minLabel: "0.5 \("unit.kg".l)",
                            maxLabel: "6 \("unit.kg".l)",
                            color: BBTheme.Colors.growth
                        )
                    }

                    // ── Prematurity ───────────────────────────────────────
                    formSection {
                        BBOptionalMeasureToggle(
                            title: "form.preterm".l,
                            hint: "form.preterm_hint".l,
                            isOn: $wasBornEarly,
                            value: $gestationalWeeks,
                            range: 22...36, step: 1,
                            display: "\(Int(gestationalWeeks)) \("unit.weeks_short".l)",
                            minLabel: "22 \("unit.weeks_short".l)",
                            maxLabel: "36 \("unit.weeks_short".l)",
                            color: BBTheme.Colors.accent
                        )
                    }

                    // ── Gender ────────────────────────────────────────────
                    formSection {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            Text("profile.gender".l)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                            HStack(spacing: BBTheme.Spacing.sm) {
                                ForEach(Baby.Gender.allCases, id: \.self) { gender in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            editedGender = gender
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: gender == .male ? "figure.stand" : "figure.stand.dress")
                                            Text(gender.displayName.l)
                                                .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                                        }
                                        .foregroundStyle(editedGender == gender ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(editedGender == gender ? BBTheme.Colors.primary.opacity(0.12) : BBTheme.Colors.surface)
                                        .cornerRadius(BBTheme.Radius.md)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                                                .strokeBorder(editedGender == gender ? BBTheme.Colors.primary : Color.clear, lineWidth: 1.5)
                                        )
                                        .bbShadow(BBTheme.Shadow.card)
                                    }
                                    .buttonStyle(BBScaleButtonStyle())
                                }
                            }
                        }
                    }

                    // ── Feeding type ──────────────────────────────────────
                    formSection {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            Text("profile.feeding".l)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                            HStack(spacing: BBTheme.Spacing.sm) {
                                ForEach(Baby.FeedingType.allCases, id: \.self) { ft in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            editedFeedingType = ft
                                        }
                                    } label: {
                                        Text(ft.displayName.l)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(editedFeedingType == ft ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(editedFeedingType == ft ? BBTheme.Colors.primary.opacity(0.12) : BBTheme.Colors.surface)
                                            .cornerRadius(BBTheme.Radius.md)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                                                    .strokeBorder(editedFeedingType == ft ? BBTheme.Colors.primary : Color.clear, lineWidth: 1.5)
                                            )
                                            .bbShadow(BBTheme.Shadow.card)
                                    }
                                    .buttonStyle(BBScaleButtonStyle())
                                }
                            }
                        }
                    }

                    Spacer(minLength: BBTheme.Spacing.xl)
                }
                .padding(BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            // Big primary action pinned to the safe area for one-handed / night use;
            // mirrors the toolbar Save (both call save()).
            .safeAreaInset(edge: .bottom) {
                BBPrimaryButton("button.save".l, icon: "checkmark") { save() }
                    .padding(.horizontal, BBTheme.Spacing.md)
                    .padding(.top, BBTheme.Spacing.sm)
                    .padding(.bottom, BBTheme.Spacing.xs)
                    .background(BBTheme.Colors.background)
            }
            .navigationTitle("profile.edit_title".l)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save".l) { save() }
                        .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                }
            }
        }
        .presentationDragIndicator(.visible)
        // Profile is a tall, deliberate edit form (avatar + 6 form sections);
        // .large only — .medium would crop the feeding-type row under the fold.
        .presentationDetents([.large])
        .onChange(of: selectedPhotoItem) { _, item in
            loadPhoto(item)
        }
        .alert("profile.remove_photo".l, isPresented: $showRemovePhotoAlert) {
            Button("button.delete".l, role: .destructive) { editedPhotoData = nil }
            Button("button.cancel".l, role: .cancel) {}
        }
    }

    // MARK: - Avatar section

    private var avatarSection: some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                BabyAvatarView(photoData: editedPhotoData, gender: editedGender, size: 100)
                    .overlay(Circle().stroke(BBTheme.Colors.surface, lineWidth: 3))

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(BBTheme.Colors.primary)
                            .frame(width: 30, height: 30)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)      // ≥44pt tap zone (visual stays 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if editedPhotoData != nil {
                Button {
                    showRemovePhotoAlert = true
                } label: {
                    Text("profile.remove_photo".l)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            } else {
                Text("profile.photo_hint".l)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, BBTheme.Spacing.md)
    }

    // MARK: - Helpers

    /// Recomputed per body evaluation rather than stored: it depends on `now`,
    /// and the sheet can sit open across midnight.
    private var latestSelectableBirthDate: Date {
        BirthDateChange.latestSelectableBirthDate(entries: baby.growthEntries ?? [],
                                                  oldBirthDate: baby.birthDate)
    }

    private func formSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(BBTheme.Spacing.md)
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.md)
            .bbShadow(BBTheme.Shadow.card)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Resize to max 800px before storing
                let compressed = UIImage(data: data)
                    .flatMap { resized($0, maxDimension: 800) }
                    .flatMap { $0.jpegData(compressionQuality: 0.8) }
                await MainActor.run { editedPhotoData = compressed ?? data }
            }
        }
    }

    private func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        guard ratio < 1 else { return image }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func saveName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { baby.name = trimmed }
    }

    /// Commits the buffered birth date, taking the birth measurements with it.
    ///
    /// This is the one field on the sheet whose correction reaches history, and
    /// it has to: the entries dated on the old birth day ARE the birth
    /// measurements by construction, so leaving them behind strands them before
    /// the new birth date, where the growth engine reads them as bad data.
    /// `BirthDateChange` owns both rules — which entries move, and how far the
    /// date itself may — and documents why.
    private func saveBirthDate() {
        let newBirthDate = BirthDateChange.commit(selected: editedBirthDate,
                                                  oldBirthDate: baby.birthDate,
                                                  entries: baby.growthEntries ?? [])
        guard newBirthDate != baby.birthDate else { return }
        // Selected against the OLD birth date, before it is overwritten.
        let birthMeasurements = BirthDateChange.entriesToRedate(
            entries: baby.growthEntries ?? [],
            oldBirthDate: baby.birthDate
        )
        for entry in birthMeasurements { entry.date = newBirthDate }
        baby.birthDate = newBirthDate
    }

    private func save() {
        saveName()
        saveBirthDate()
        baby.gender = editedGender
        baby.feedingType = editedFeedingType
        baby.photoData = editedPhotoData
        // Toggling either off clears the stored value: the parent is saying they
        // do not know it, which is not the same as leaving a stale number behind.
        baby.birthWeightKg = recordsBirthWeight ? birthWeightKg : nil
        baby.gestationalWeeks = wasBornEarly ? Int(gestationalWeeks) : nil
        try? modelContext.save()
        // A rename has to reach the widget, which prints the name.
        WidgetRefresh.profileChanged()
        // Every other growth mutation re-derives the notifications from the
        // surviving data, and this is one: the birth date moves the weigh-in
        // reminder, the newborn flag and the gain signal, and the re-dated birth
        // measurement is an input to all three. Waiting for the next `GrowthView`
        // visit would leave a reminder scheduled off the old date free to fire
        // first. Cancel-before-add, so calling it here is safe.
        // `?? []`, not `if let`: with no entries at all the schedule is purely
        // date-driven (the weigh-in reminder hangs off `birthDate`), which is
        // the one case that must not skip the refresh.
        NotificationManager.shared.onGrowthDataChanged(
            baby: baby,
            entries: baby.growthEntries ?? [],
            isPremium: store.isPremium
        )
        dismiss()
    }
}
