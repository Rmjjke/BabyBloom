import SwiftUI

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
