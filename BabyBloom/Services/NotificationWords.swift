import Foundation
import UserNotifications

/// The keys and arguments a scheduled notification was written from, kept in
/// its `userInfo` so the text can be written again in another language.
///
/// A pending request holds resolved strings: after a language change it would
/// fire in the old one. Most kinds cannot be planned again from the store,
/// since the moment they count from (a save, the first feed) is not kept, so
/// the request is re-worded in place and keeps its fire moment.
struct NotificationWords: Equatable, Sendable {
    struct Line: Equatable, Sendable {
        let key: String
        let args: [String]

        /// Every argument goes through `arg(_:)`: the only arguments today
        /// are the baby's name, and its localized default must follow the
        /// language too.
        init(_ key: String, _ args: String...) {
            self.key = key
            self.args = args.map(NotificationWords.arg)
        }

        fileprivate init(stored key: String, args: [String]) {
            self.key = key
            self.args = args
        }

        /// The line in the app's current language.
        var resolved: String {
            guard !args.isEmpty else { return key.l }
            return String(format: key.l, arguments: args.map(NotificationWords.resolve))
        }
    }

    let title: Line
    let body: Line
    /// When a time-interval request fires. Read back from the centre, such a
    /// trigger reports `nextTriggerDate()` as now plus its interval, so the
    /// moment is stored rather than asked for.
    let fireAt: Date?

    static let userInfoKey = "bb.words"
    private static let markerPrefix = "@l:"
    private static let defaultNameKey = "baby.default_name"

    /// The current language's default name becomes a marker, resolved again
    /// at each wording; any other argument is kept as given.
    static func arg(_ value: String) -> String {
        value == defaultNameKey.l ? markerPrefix + defaultNameKey : value
    }

    static func resolve(_ arg: String) -> String {
        arg.hasPrefix(markerPrefix) ? String(arg.dropFirst(markerPrefix.count)).l : arg
    }

    /// Plist types only: `userInfo` is archived with the request.
    var userInfo: [String: Any] {
        var words: [String: Any] = ["title": [title.key] + title.args, "body": [body.key] + body.args]
        if let fireAt { words["fireAt"] = fireAt.timeIntervalSince1970 }
        return [Self.userInfoKey: words]
    }

    init(title: Line, body: Line, fireAt: Date?) {
        self.title = title
        self.body = body
        self.fireAt = fireAt
    }

    /// Nil for a request that carries no words: one from an earlier build,
    /// or a medication reminder, which is planned again from the store.
    init?(userInfo: [AnyHashable: Any]) {
        guard let words = userInfo[Self.userInfoKey] as? [String: Any],
              let title = words["title"] as? [String], let titleKey = title.first,
              let body = words["body"] as? [String], let bodyKey = body.first else { return nil }
        self.title = Line(stored: titleKey, args: Array(title.dropFirst()))
        self.body = Line(stored: bodyKey, args: Array(body.dropFirst()))
        fireAt = (words["fireAt"] as? Double).map(Date.init(timeIntervalSince1970:))
    }
}

/// The part of the notification centre `NotificationManager` uses; tests pass
/// a fake.
protocol NotificationCenterSeam: Sendable {
    func pending() async -> [UNNotificationRequest]
    /// Queued in call order, as the centre's own `add` is: a cancel and the
    /// add that follows it must not swap.
    func add(_ request: UNNotificationRequest, then: (@Sendable () -> Void)?)
    func remove(_ identifiers: [String])
}

extension NotificationCenterSeam {
    func add(_ request: UNNotificationRequest) { add(request, then: nil) }
}

struct SystemNotificationCenter: NotificationCenterSeam {
    func pending() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }

    func add(_ request: UNNotificationRequest, then: (@Sendable () -> Void)?) {
        UNUserNotificationCenter.current().add(request) { _ in then?() }
    }

    func remove(_ identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

enum NotificationRewording {
    /// Adds every pending request that carries words again under its own id,
    /// written in the current language. A calendar trigger is kept as it is;
    /// a time-interval one gets the time left. Under a second left, the
    /// request is left alone: it fires in the old language either way.
    /// `skipping` names the ids added or removed since the pending list was
    /// read: the copy here is older than them and must not be put back.
    /// On the main actor, where the manager posts, so no post lands between
    /// that check and the add. Returns the ids re-worded.
    @MainActor
    @discardableResult
    static func reword(center: NotificationCenterSeam, now: Date,
                       skipping: () -> Set<String> = { [] }) async -> [String] {
        var reworded: [String] = []
        for request in await center.pending() {
            guard !skipping().contains(request.identifier),
                  let words = NotificationWords(userInfo: request.content.userInfo),
                  let trigger = trigger(for: request.trigger, words: words, now: now),
                  let content = request.content.mutableCopy() as? UNMutableNotificationContent
            else { continue }
            content.title = words.title.resolved
            content.body = words.body.resolved
            center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
            reworded.append(request.identifier)
        }
        return reworded
    }

    private static func trigger(for old: UNNotificationTrigger?, words: NotificationWords,
                                now: Date) -> UNNotificationTrigger? {
        switch old {
        case let calendar as UNCalendarNotificationTrigger:
            return calendar
        // A repeating interval counts from its add, whatever is stored.
        case let interval as UNTimeIntervalNotificationTrigger where interval.repeats:
            return interval
        case is UNTimeIntervalNotificationTrigger:
            guard let left = words.fireAt?.timeIntervalSince(now), left >= 1 else { return nil }
            return UNTimeIntervalNotificationTrigger(timeInterval: left, repeats: false)
        default:
            return nil
        }
    }
}
