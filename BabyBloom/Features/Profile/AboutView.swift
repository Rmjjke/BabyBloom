import SwiftUI
import CloudKit

/// Settings' read-only iCloud Sync line. Asks CloudKit itself:
/// the store syncs through CloudKit only, and the ubiquity token can be nil
/// for a signed-in account with iCloud Drive off, which would read as "Off"
/// while sync works.
struct ICloudStatusRow: View {
    /// nil until CloudKit answers: no value rather than a guessed one.
    @State private var isOn: Bool?

    var body: some View {
        // One label around the title, the value and the hint, as the switch
        // rows hold theirs: the value and the hint start at the title's x.
        SettingsRowLabel(systemImage: "icloud.fill") {
            VStack(alignment: .leading, spacing: 2) {
                // By fit: on a 320 pt window the ru and es titles miss one line
                // beside the value at Large, and side by side the title broke
                // inside its words («Синхро / низация»).
                BBValueRow(shape: .byFit, underSpacing: 2) {
                    Text("settings.icloud".l)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                } value: {
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
        } words: {
            Text("settings.icloud".l.oneWordALine)
            if let isOn {
                Text((isOn ? "settings.icloud_on" : "settings.icloud_off").l.oneWordALine)
            }
            if isOn == false {
                Text("settings.icloud_off_hint".l.oneWordALine)
                    .font(.footnote)
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
