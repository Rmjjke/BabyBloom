import SwiftUI

/// A Settings row's icon and texts: the system Label while every word of the
/// texts fits beside the icon, else the icon on a line of its own above the
/// texts, xs 4 apart; chosen by fit at every text size. At the accessibility
/// sizes the Label sets the icon into the first line of every text, and
/// «Синхронизация» broke inside itself at AX2 on a 320-pt screen. The probe
/// holds every word, not each text's first: with no size gate, a later word
/// that misses its room beside the icon breaks there as well.
struct SettingsRowLabel<Texts: View, Words: View>: View {
    let systemImage: String
    /// One view: the texts' column.
    @ViewBuilder let texts: () -> Texts
    /// Each text one word a line, in the font it is drawn in: its ideal width
    /// is the widest word, what must fit beside the icon.
    @ViewBuilder let words: () -> Words

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ProbedIdealWidth {
                Label {
                    texts()
                } icon: {
                    RowIcon(systemImage: systemImage)
                }
                IconColumn(systemImage: systemImage)
                // The body font set here, as the List's Label sets it on
                // its title: a word left on the default font beside the
                // Label measured without Bold Text and passed for fitting.
                VStack(alignment: .leading, spacing: 0) { words() }
                    .font(.body)
                    .hidden()
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
                RowIcon(systemImage: systemImage)
                texts()
            }
            .font(.body)
        }
    }
}

/// A list row's icon and title, as More's rows below the first: the system
/// Label while the title's widest word fits beside the icon, else the icon on
/// a line of its own above the title, xs 4 apart; chosen by fit at every text
/// size. At AX2 on a 320-pt screen the Label left a title about 158 pt beside
/// its icon and split «Medica-tions», «Crec-imiento» and «Лекарств/а». A word
/// wider than the whole row is drawn smaller, at AX1 and then at xxxLarge, so
/// it stays whole while it fits the row at xxxLarge: with Bold Text es
/// «Medicamentos» takes 221.6 pt at AX2 in a 218-pt row. The app's text sizes
/// stop at AX2.
struct ListTitleRowLabel: View {
    let title: String
    let systemImage: String
    var iconColor: Color = BBTheme.Colors.textPrimary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ProbedIdealWidth {
                Label {
                    Text(title)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                } icon: {
                    RowIcon(systemImage: systemImage, color: iconColor)
                }
                IconColumn(systemImage: systemImage)
                Text(title.oneWordALine)
                    .font(.body)
                    .hidden()
                    .accessibilityHidden(true)
            }
            under(at: dynamicTypeSize)
            under(at: min(dynamicTypeSize, .accessibility1))
            under(at: min(dynamicTypeSize, .xxxLarge))
        }
    }

    /// Under the icon the title has the row's whole width; its ideal width is
    /// its widest word at `size`, so the row keeps a size only while that word
    /// fits.
    private func under(at size: DynamicTypeSize) -> some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
            RowIcon(systemImage: systemImage, color: iconColor)
            WordWrappingText(text: title)
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .dynamicTypeSize(size)
        }
        .font(.body)
    }
}

private struct RowIcon: View {
    let systemImage: String
    var color: Color = BBTheme.Colors.textPrimary

    var body: some View {
        Image(systemName: systemImage)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

/// The icon's column: the List's Label with nothing beside it.
private struct IconColumn: View {
    let systemImage: String

    var body: some View {
        Label {
            Color.clear.frame(width: 0, height: 0)
        } icon: {
            Image(systemName: systemImage)
        }
        .hidden()
        .accessibilityHidden(true)
    }
}

/// The baby's row at the top of Settings: the avatar beside the name and the
/// age while every word keeps whole there, else the avatar on a line of its
/// own above them; chosen by fit at every text size. Beside the 56-pt avatar
/// on a 320-pt screen the column split «Алекса|ндра» at AX2 and «Александ|ра»
/// at xxxLarge, and with Bold Text the glued «11 месяцев» missed it too: a
/// glued phrase wider than its line is broken at its no-break space, so
/// «месяцев» started a line alone.
struct SettingsBabyRowLabel: View {
    let baby: Baby

    var body: some View {
        let age = baby.ageDescription
        ViewThatFits(in: .horizontal) {
            ProbedIdealWidth {
                beside(name: baby.name, age: age)
                // The same row one word a line: its ideal width is the
                // narrowest the drawn row keeps every word whole at. The
                // age's no-break space keeps it one word here.
                beside(name: baby.name.oneWordALine, age: age.oneWordALine)
                    .hidden()
                    .accessibilityHidden(true)
            }
            // The chevron rides the avatar's line, so the texts get the
            // row's whole width: beside them it still split a bold
            // «Александра» at AX2.
            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                HStack {
                    avatar
                    Spacer(minLength: 0)
                    chevron
                }
                texts(name: baby.name, age: age)
            }
        }
    }

    private func beside(name: String, age: String) -> some View {
        HStack(spacing: BBTheme.Spacing.md) {
            avatar
            texts(name: name, age: age)
            Spacer()
            chevron
        }
    }

    private func texts(name: String, age: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(BBTheme.Typography.scaled(20, relativeTo: .title3, weight: .semibold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Text(age)
                .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.primary)
        }
    }

    private var avatar: some View {
        BabyAvatarView(photoData: baby.photoData, gender: baby.gender, size: 56)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(BBTheme.Colors.textSecondary.opacity(0.4))
    }
}

/// Draws its first subview, a system row, as the system sizes it; asked its
/// ideal width, it answers the sum of the other subviews' ideal widths: hidden
/// probes whose width is the narrowest the row keeps every word whole at.
/// The drawn row cannot measure itself: at the accessibility sizes a Label's
/// own ideal width is its icon's column alone (59.7 pt at AX2), which every
/// row fits, and a switch whose label answered a custom ideal stood its List
/// row as tall as that label's ideal, cutting or stretching it.
private struct ProbedIdealWidth: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let drawn = subviews[0].sizeThatFits(proposal)
        guard proposal.width == nil else { return drawn }
        let width = subviews.dropFirst().reduce(0) { $0 + $1.sizeThatFits(.unspecified).width }
        return CGSize(width: width, height: drawn.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        for probe in subviews.dropFirst() {
            probe.place(at: bounds.origin, proposal: .zero)
        }
    }
}

/// A Settings switch with a line under its title: what the switch does or
/// when its notification comes. The switch stands beside the texts while every
/// word keeps whole there, else under them at the title's x, sm 8 under the
/// hint; under at every accessibility size. VoiceOver reads one switch with
/// the title and the hint either way.
struct SettingsSwitchRow: View {
    let title: String
    let hint: String
    let systemImage: String
    @Binding var isOn: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            under
        } else {
            ViewThatFits(in: .horizontal) {
                ProbedIdealWidth {
                    beside
                    // The same row one word a line: its ideal width is the
                    // narrowest the drawn row keeps every word whole at.
                    Toggle(isOn: .constant(false)) {
                        Label {
                            texts(title.oneWordALine, hint.oneWordALine)
                        } icon: {
                            icon
                        }
                    }
                    .hidden()
                    .accessibilityHidden(true)
                }
                under
            }
        }
    }

    /// The system row.
    private var beside: some View {
        Toggle(isOn: $isOn) {
            Label {
                texts(title, hint)
            } icon: {
                icon
            }
        }
    }

    /// The switch in the texts' column, where it starts at the title's x
    /// whether the icon stands beside or above.
    private var under: some View {
        SettingsRowLabel(systemImage: systemImage) {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                // The switch carries these words for VoiceOver: read beside
                // it, the List row merged them into one element that read the
                // hint alone.
                texts(title, hint)
                    .accessibilityHidden(true)
                Toggle(isOn: $isOn) {
                    texts(title, hint)
                }
                .labelsHidden()
                .fixedSize()
            }
        } words: {
            Text(title.oneWordALine)
            Text(hint.oneWordALine)
                .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .foregroundStyle(BBTheme.Colors.textPrimary)
    }

    private func texts(_ title: String, _ hint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Text(hint)
                .font(.footnote)
                .foregroundStyle(BBTheme.Colors.textSecondary)
        }
    }
}
