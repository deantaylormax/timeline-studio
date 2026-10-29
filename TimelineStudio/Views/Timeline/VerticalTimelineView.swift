import SwiftUI

/// The hero layout: a continuous spine with events attached as cards.
/// `alternating` centers the spine and places cards on both sides.
struct VerticalTimelineView: View {
    let months: [MonthGroup]
    let alternating: Bool
    let showTimes: Bool

    @Environment(\.isExporting) private var isExporting
    private let sideIndex: [UUID: Int]

    init(months: [MonthGroup], alternating: Bool, showTimes: Bool) {
        self.months = months
        self.alternating = alternating
        self.showTimes = showTimes
        var index: [UUID: Int] = [:]
        var position = 0
        for month in months {
            for day in month.days {
                for event in day.events {
                    index[event.id] = position
                    position += 1
                }
            }
        }
        sideIndex = index
    }

    var body: some View {
        if isExporting {
            VStack(spacing: 0) { rows }
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) { rows }
                    .supportsDividerDragging(axis: .vertical)
                    .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private var rows: some View {
        SpineRow(alternating: alternating, spine: .fadeIn) { Color.clear.frame(height: 18) }

        ForEach(months) { month in
            Section {
                ForEach(month.days) { day in
                    DayMarkerRow(day: day.date, count: day.events.count, alternating: alternating)
                    ForEach(day.entries) { entry in
                        switch entry {
                        case .event(let event):
                            EventRow(event: event,
                                     alternating: alternating,
                                     cardOnLeading: (sideIndex[event.id] ?? 0) % 2 == 1,
                                     showTimes: showTimes)
                                .reportsEntryFrame(id: event.id, date: event.date)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
                                    removal: .opacity))
                        case .divider(let divider):
                            SpineRow(alternating: alternating) {
                                HorizontalDividerBand(divider: divider)
                                    .padding(.vertical, 18)
                            }
                            .draggableDivider(divider, axis: .vertical)
                            .reportsEntryFrame(id: divider.id, date: divider.date)
                            .transition(.opacity)
                        }
                    }
                }
            } header: {
                MonthMarker(title: month.title, alternating: alternating)
            }
        }

        SpineRow(alternating: alternating, spine: .fadeOut) { Color.clear.frame(height: 36) }
    }
}

// MARK: - Spine row

enum SpineStyle { case solid, fadeIn, fadeOut }

/// Wraps a row in the centered content column and draws its segment of the spine,
/// so consecutive rows form one continuous line.
struct SpineRow<Content: View>: View {
    var alternating: Bool
    var spine: SpineStyle = .solid
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: TimelineMetrics.maxContentWidth, alignment: alternating ? .center : .leading)
            .background(alignment: alternating ? .top : .topLeading) {
                spineLine
                    .padding(.leading, alternating ? 0 : TimelineMetrics.spineX - 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
    }

    @ViewBuilder
    private var spineLine: some View {
        switch spine {
        case .solid:
            Rectangle().fill(Palette.spine).frame(width: 2)
        case .fadeIn:
            Rectangle()
                .fill(LinearGradient(colors: [Palette.spine.opacity(0), Palette.spine], startPoint: .top, endPoint: .bottom))
                .frame(width: 2)
        case .fadeOut:
            Rectangle()
                .fill(LinearGradient(colors: [Palette.spine, Palette.spine.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 2)
        }
    }
}

// MARK: - Markers

struct MonthMarker: View {
    let title: String
    let alternating: Bool
    @Environment(\.isExporting) private var isExporting

    var body: some View {
        SpineRow(alternating: alternating) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .surface(Capsule(), exporting: isExporting)
                .alignmentGuide(.leading) { d in alternating ? d[.leading] : d.width / 2 - TimelineMetrics.spineX }
                .frame(maxWidth: .infinity, alignment: alternating ? .center : .leading)
                .padding(.vertical, 12)
        }
    }
}

struct DayMarkerRow: View {
    let day: Date
    let count: Int
    let alternating: Bool
    @Environment(\.canvasBaseColor) private var baseColor

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        SpineRow(alternating: alternating) {
            HStack(spacing: 0) {
                if alternating {
                    dayStamp.frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 4)
                    dot.frame(width: TimelineMetrics.nodeColumn)
                    fullDate.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
                } else {
                    dayStamp.frame(width: TimelineMetrics.timeColumn - 6, alignment: .trailing).padding(.trailing, 6)
                    dot.frame(width: TimelineMetrics.nodeColumn)
                    fullDate
                    Spacer(minLength: 0)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 4)
        }
    }

    private var dayStamp: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isToday ? Color.accentColor : .secondary)
            Text(day.formatted(.dateTime.day()))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(isToday ? Color.accentColor : .primary)
        }
    }

    private var dot: some View {
        Circle()
            .fill(isToday ? Color.accentColor : Palette.dayDot)
            .frame(width: 9, height: 9)
            .padding(3)
            .background(Circle().fill(baseColor))
    }

    private var fullDate: some View {
        let date = day.formatted(.dateTime.month(.wide).day().year())
        let label = isToday ? "Today · \(date)" : date
        return Text(count > 1 ? "\(label) · \(count) events" : label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Event row

struct EventRow: View {
    let event: TimelineEvent
    let alternating: Bool
    let cardOnLeading: Bool
    let showTimes: Bool
    @Environment(\.categoryCatalog) private var catalog
    @Environment(\.isExporting) private var isExporting

    var body: some View {
        let category = catalog.category(for: event.categoryID)
        SpineRow(alternating: alternating) {
            HStack(alignment: .top, spacing: 0) {
                if alternating {
                    Group {
                        if cardOnLeading { card(category, maxWidth: 380) } else { timeLabel }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    TimelineNode(category: category)
                        .frame(width: TimelineMetrics.nodeColumn)
                        .padding(.top, 10)
                    Group {
                        if cardOnLeading { timeLabel } else { card(category, maxWidth: 380) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    timeLabel
                        .frame(width: TimelineMetrics.timeColumn, alignment: .trailing)
                    TimelineNode(category: category)
                        .frame(width: TimelineMetrics.nodeColumn)
                        .padding(.top, 10)
                    card(category, maxWidth: 620)
                }
            }
            .padding(.vertical, 7)
        }
    }

    private func card(_ category: EventCategory, maxWidth: CGFloat) -> some View {
        EventCard(event: event, category: category, maxWidth: maxWidth)
            .scrollTransition(isExporting ? .identity : .interactive, axis: .vertical) { content, phase in
                content
                    .opacity(1 - abs(phase.value) * 0.4)
                    .scaleEffect(1 - abs(phase.value) * 0.02)
            }
    }

    private var timeLabel: some View {
        Text(showTimes ? (event.isAllDay ? "All-day" : event.date.formatted(date: .omitted, time: .shortened)) : " ")
            .font(.system(size: 11.5, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.top, 21)
            .padding(.horizontal, 6)
    }
}
