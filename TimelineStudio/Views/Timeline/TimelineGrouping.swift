import Foundation

/// One item on a timeline: an event, or a chapter divider.
enum TimelineEntry: Identifiable {
    case event(TimelineEvent)
    case divider(TimelineDivider)

    var id: UUID {
        switch self {
        case .event(let event): event.id
        case .divider(let divider): divider.id
        }
    }

    var date: Date {
        switch self {
        case .event(let event): event.date
        case .divider(let divider): divider.date
        }
    }
}

struct DayGroup: Identifiable {
    let date: Date
    let entries: [TimelineEntry]

    /// Distinct from MonthGroup's id: the 1st of a month and the month itself share a date, and in a
    /// lazy stack the clash made that day's marker row vanish.
    var id: String { "day-\(date.timeIntervalSince1970)" }

    var events: [TimelineEvent] {
        entries.compactMap { if case .event(let event) = $0 { event } else { nil } }
    }
}

struct MonthGroup: Identifiable {
    let date: Date
    let days: [DayGroup]

    var id: String { "month-\(date.timeIntervalSince1970)" }
    var title: String { date.formatted(.dateTime.month(.wide).year()) }
}

enum TimelineGrouping {
    /// Merges dividers into already-ordered events. A divider goes just before any event at the same
    /// instant, so "Add Divider Before" lands where expected in either sort direction.
    static func entries(events: [TimelineEvent], dividers: [TimelineDivider], newestFirst: Bool) -> [TimelineEntry] {
        let sortedDividers = dividers.sorted { newestFirst ? $0.date > $1.date : $0.date < $1.date }
        var result: [TimelineEntry] = []
        result.reserveCapacity(events.count + sortedDividers.count)
        var next = 0
        for event in events {
            while next < sortedDividers.count,
                  newestFirst ? sortedDividers[next].date >= event.date : sortedDividers[next].date <= event.date {
                result.append(.divider(sortedDividers[next]))
                next += 1
            }
            result.append(.event(event))
        }
        result += sortedDividers[next...].map(TimelineEntry.divider)
        return result
    }

    /// Groups already-ordered entries into month and day sections, preserving their order.
    static func months(from entries: [TimelineEntry]) -> [MonthGroup] {
        let calendar = Calendar.current
        var months: [MonthGroup] = []
        var currentMonth: Date?
        var days: [DayGroup] = []
        var currentDay: Date?
        var dayEntries: [TimelineEntry] = []

        func flushDay() {
            if let currentDay, !dayEntries.isEmpty { days.append(DayGroup(date: currentDay, entries: dayEntries)) }
            dayEntries = []
        }
        func flushMonth() {
            flushDay()
            if let currentMonth, !days.isEmpty { months.append(MonthGroup(date: currentMonth, days: days)) }
            days = []
        }

        for entry in entries {
            let month = calendar.dateInterval(of: .month, for: entry.date)?.start ?? entry.date
            let day = calendar.startOfDay(for: entry.date)
            if month != currentMonth {
                flushMonth()
                currentMonth = month
                currentDay = day
            } else if day != currentDay {
                flushDay()
                currentDay = day
            }
            dayEntries.append(entry)
        }
        flushMonth()
        return months
    }

    /// e.g. "16 events · Jun 2026 – Sep 2026"
    static func summary(for events: [TimelineEvent]) -> String {
        guard let first = events.map(\.date).min(), let last = events.map(\.date).max() else { return "" }
        let count = events.count == 1 ? "1 event" : "\(events.count) events"
        let style = Date.FormatStyle.dateTime.month(.abbreviated).year()
        let start = first.formatted(style)
        let end = last.formatted(style)
        return start == end ? "\(count) · \(start)" : "\(count) · \(start) – \(end)"
    }
}
