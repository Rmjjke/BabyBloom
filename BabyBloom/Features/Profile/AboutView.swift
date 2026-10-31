import SwiftUI
import CloudKit

/// Settings' read-only iCloud Sync line (Q-003, D21). Asks CloudKit itself:
/// the store syncs through CloudKit only, and the ubiquity token can be nil
/// for a signed-in account with iCloud Drive off, which would read as "Off"
/// while sync works.
struct ICloudStatusRow: View {
    /// nil until CloudKit answers: no value rather than a guessed one.
    @State private var isOn: Bool?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Value under the label at accessibility sizes: side by side, ru
            // AX2 broke «Синхро / низация» and «Выключен / а» (Q-013).
            let row = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout())
            row {
                Label("settings.icloud".l, systemImage: "icloud.fill")
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                if let isOn {
                    Text((isOn ? "settings.icloud_on" : "settings.icloud_off").l)
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
            if isOn == false {
                Text("settings.icloud_off_hint".l)
                    .font(.footnote)
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.icloud")
        .task { await refresh() }
        // Signing in from the Settings app and coming back updates the line.
        .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
            Task { await refresh() }
        }
    }

    private func refresh() async {
        let status = try? await CKContainer(identifier: "iCloud.com.nenita.app").accountStatus()
        isOn = status == .available
    }
}

/// The legal pages, shared by the paywall footer and the About screen: the
/// store listing, the paywall and this screen must point at the same documents.
enum LegalLinks {
    static let terms = URL(string: "https://bitty.okapps.org/bitty/terms")!
    static let privacy = URL(string: "https://bitty.okapps.org/bitty/privacy")!
}

struct AboutView: View {
    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String
        let version = build.map { "\(short) (\($0))" } ?? short
        return String(format: "about.version_fmt".l, version)
    }

    var body: some View {
        List {
            Section {
                Text(versionText)
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                    .accessibilityIdentifier("settings.about.version")
            }
            Section {
                Link("premium.terms".l, destination: LegalLinks.terms)
                    .accessibilityIdentifier("settings.about.terms")
                Link("premium.privacy".l, destination: LegalLinks.privacy)
                    .accessibilityIdentifier("settings.about.privacy")
            }
        }
        .navigationTitle("settings.about".l)
        .navigationBarTitleDisplayMode(.inline)
    }
}
