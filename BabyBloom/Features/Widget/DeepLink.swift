import Foundation

/// The app's URLs: `nenita://tab/<destination>`. The widget's tap areas build
/// them, `MainTabView` follows them, and QA opens them with `simctl openurl`
/// (lever L4). The scheme is registered in Info.plist only for that last use:
/// a widget link reaches its own app without one.
enum DeepLink {
    static let scheme = "nenita"

    enum Destination: String, CaseIterable, Sendable {
        case home, feeding, sleep, diapers
    }

    static func url(_ destination: Destination) -> URL {
        URL(string: "\(scheme)://tab/\(destination.rawValue)")!
    }

    /// Nil for anything else, so an unknown link opens the app where it was.
    static func destination(from url: URL) -> Destination? {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == "tab" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 1 else { return nil }
        return Destination(rawValue: parts[0].lowercased())
    }
}
