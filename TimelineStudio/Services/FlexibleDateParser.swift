import Foundation

/// Parses dates written in the many formats people use in spreadsheets.
/// US ordering (MM/DD) is preferred when a date is ambiguous.
enum FlexibleDateParser {
    struct Result {
        let date: Date
        let hasTime: Bool
    }

    private static let dateTimeFormats = [
        "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd h:mm a", "yyyy-MM-dd h:mma",
        "yyyy/MM/dd HH:mm", "yyyy/MM/dd h:mm a",
        "M/d/yyyy H:mm:ss", "M/d/yyyy H:mm", "M/d/yyyy h:mm a", "M/d/yyyy h:mma", "M/d/yyyy h:mm:ss a",
        "M/d/yy H:mm", "M/d/yy h:mm a",
        "d/M/yyyy H:mm", "d/M/yyyy h:mm a",
        "MMM d, yyyy h:mm a", "MMMM d, yyyy h:mm a", "MMM d, yyyy HH:mm", "MMMM d, yyyy HH:mm",
        "MMM d yyyy h:mm a", "d MMM yyyy HH:mm", "d MMMM yyyy HH:mm",
        "EEE, MMM d, yyyy h:mm a", "EEEE, MMMM d, yyyy h:mm a",
    ]

    private static let dateOnlyFormats = [
        "yyyy-MM-dd", "yyyy/MM/dd", "yyyy.MM.dd", "yyyyMMdd",
        "M/d/yyyy", "M/d/yy", "M-d-yyyy", "M-d-yy", "d/M/yyyy", "d.M.yyyy", "d.M.yy",
        "MMM d, yyyy", "MMMM d, yyyy", "MMM d yyyy", "MMMM d yyyy",
        "d MMM yyyy", "d MMMM yyyy", "d-MMM-yyyy", "d-MMM-yy",
        "EEE, MMM d, yyyy", "EEEE, MMMM d, yyyy", "EEE MMM d yyyy",
        "MMM yyyy", "MMMM yyyy",
    ]

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.isLenient = false
        formatter.dateFormat = format
        return formatter
    }

    private static let dateTimeFormatters = dateTimeFormats.map(makeFormatter)
    private static let dateOnlyFormatters = dateOnlyFormats.map(makeFormatter)
    private static let ordinalRegex = try? NSRegularExpression(pattern: "(\\d)(st|nd|rd|th)\\b", options: [.caseInsensitive])

    static func parse(_ raw: String, time: String? = nil) -> Result? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let time, !time.trimmingCharacters(in: .whitespaces).isEmpty {
            text += " " + time.trimmingCharacters(in: .whitespaces)
        }
        text = cleaned(text)

        for formatter in dateTimeFormatters {
            if let date = formatter.date(from: text), isPlausible(date) {
                return Result(date: date, hasTime: true)
            }
        }
        for formatter in dateOnlyFormatters {
            if let date = formatter.date(from: text), isPlausible(date) {
                return Result(date: date, hasTime: false)
            }
        }

        let iso = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [[.withInternetDateTime, .withFractionalSeconds], [.withInternetDateTime]] {
            iso.formatOptions = options
            if let date = iso.date(from: text) { return Result(date: date, hasTime: true) }
        }

        // Unix timestamps (seconds or milliseconds).
        if let number = Double(text), number > 100_000_000 {
            let seconds = number > 100_000_000_000 ? number / 1000 : number
            return Result(date: Date(timeIntervalSince1970: seconds), hasTime: true)
        }

        // Last resort: natural-language detection ("Oct 3 at 4pm", "next Tuesday"…).
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
           let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.range.length >= text.utf16.count - 2,
           let date = match.date, isPlausible(date) {
            return Result(date: date, hasTime: text.contains(":") || text.lowercased().contains("am") || text.lowercased().contains("pm"))
        }
        return nil
    }

    private static func cleaned(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if let ordinalRegex {
            result = ordinalRegex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }
        return result
    }

    private static func isPlausible(_ date: Date) -> Bool {
        let year = Calendar.current.component(.year, from: date)
        return (1900...2200).contains(year)
    }
}
