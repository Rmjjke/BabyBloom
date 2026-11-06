import Foundation

/// A span of whole minutes as every screen, the widget and the export write
/// it: «45 min», «1 h», «1 h 15 min». Whole hours drop the minutes. Glued, so
/// a number never leaves its unit. Each caller turns its seconds into minutes
/// its own way (a clock floors, a countdown rounds up, a weekly figure
/// rounds); seconds show only under a minute and on a running timer, which
/// have their own formats.
enum DurationText {
    static func minutes(_ minutes: Int) -> String {
        let minutes = max(0, minutes)
        let text: String
        if minutes < 60 {
            text = String(format: "duration.min_only".l, minutes)
        } else {
            let hours = minutes / 60, rest = minutes % 60
            text = rest == 0
                ? String(format: "duration.h_only".l, hours)
                : String(format: "duration.h_min".l, hours, rest)
        }
        return text.gluingNumbersToUnits
    }
}
