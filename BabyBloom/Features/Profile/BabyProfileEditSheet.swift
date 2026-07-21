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
                    Text(gender == .male ? "👦" : "👶")
                        .font(.system(size: size * 0.50))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Baby Profile Edit Sheet

struct BabyProfileEditSheet: View {
    @Bindable var baby: Baby
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var editedName: String
    @State private var showRemovePhotoAlert = false

    init(baby: Baby) {
        self.baby = baby
        _editedName = State(initialValue: baby.name)
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
                                .submitLabel(.done)
                                .onSubmit { saveName() }
                        }
                    }

                    // ── Birth date ────────────────────────────────────────
                    formSection {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            Text("profile.birth_date".l)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                            DatePicker("", selection: $baby.birthDate,
                                       in: ...Date(),
                                       displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(BBTheme.Colors.primary)
                        }
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
                                            baby.gender = gender
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(gender == .male ? "👦" : "👧")
                                            Text(gender.displayName.l)
                                                .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                                        }
                                        .foregroundStyle(baby.gender == gender ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(baby.gender == gender ? BBTheme.Colors.primary.opacity(0.12) : BBTheme.Colors.surface)
                                        .cornerRadius(BBTheme.Radius.md)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                                                .strokeBorder(baby.gender == gender ? BBTheme.Colors.primary : Color.clear, lineWidth: 1.5)
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
                                            baby.feedingType = ft
                                        }
                                    } label: {
                                        Text(ft.displayName.l)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(baby.feedingType == ft ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(baby.feedingType == ft ? BBTheme.Colors.primary.opacity(0.12) : BBTheme.Colors.surface)
                                            .cornerRadius(BBTheme.Radius.md)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                                                    .strokeBorder(baby.feedingType == ft ? BBTheme.Colors.primary : Color.clear, lineWidth: 1.5)
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
        // Profile is a tall, deliberate edit form (avatar + 4 form sections);
        // .large only — .medium would crop the feeding-type row under the fold.
        .presentationDetents([.large])
        .onChange(of: selectedPhotoItem) { _, item in
            loadPhoto(item)
        }
        .alert("profile.remove_photo".l, isPresented: $showRemovePhotoAlert) {
            Button("button.delete".l, role: .destructive) { baby.photoData = nil }
            Button("button.cancel".l, role: .cancel) {}
        }
    }

    // MARK: - Avatar section

    private var avatarSection: some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                BabyAvatarView(photoData: baby.photoData, gender: baby.gender, size: 100)
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

            if baby.photoData != nil {
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
                await MainActor.run { baby.photoData = compressed ?? data }
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

    private func save() {
        saveName()
        try? modelContext.save()
        dismiss()
    }
}
