import Foundation
import SwiftData

enum SampleData {
    static let title = "Project Aurora"
    static let subtitle = "Key moments from kickoff to launch · Summer 2026"

    static func insert(into context: ModelContext) {
        let calendar = Calendar.current
        func date(_ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)) ?? .now
        }

        let events: [TimelineEvent] = [
            TimelineEvent(date: date(6, 2, 9, 15), categoryID: EventCategory.emailID,
                          title: "Kickoff invitation from Priya",
                          notes: "Agenda attached: scope, timeline, owners. Asked everyone to skim the creative brief before Thursday."),
            TimelineEvent(date: date(6, 4, 10), categoryID: EventCategory.meetingID,
                          title: "Project kickoff",
                          notes: "Aligned on three launch pillars: story, craft, and community.\nSam owns the physical installation; Priya owns partnerships; I own the narrative and the deck.\nOpen question: do we need a second venue?",
                          location: "Studio B, 4th floor"),
            TimelineEvent(date: date(6, 4, 17, 42), categoryID: EventCategory.messageID,
                          title: "Sam: “Great start today 🎉”",
                          notes: "Shared the whiteboard photos in the team thread."),
            TimelineEvent(date: date(6, 11, 14, 30), categoryID: EventCategory.callID,
                          title: "Vendor call with Lumen Print",
                          notes: "Quoted 3-week turnaround on large-format pieces. They can hold pricing until July 15 if we confirm quantities."),
            TimelineEvent(date: date(6, 18, 11, 5), categoryID: EventCategory.purchaseID,
                          title: "Prototype materials",
                          notes: "Foam board, acrylic samples, and two LED strips for the lighting test.",
                          location: "Blick Art Materials", amount: 248.60),
            TimelineEvent(date: date(6, 18, 19, 30), categoryID: EventCategory.outingID,
                          title: "Team dinner",
                          notes: "Celebrated the first prototype. Great energy — Priya pitched the idea of a launch-night walkthrough.",
                          location: "Nopa, San Francisco"),
            TimelineEvent(date: date(7, 2), isAllDay: true, categoryID: EventCategory.noteID,
                          title: "Design review feedback compiled",
                          notes: "Top themes:\n• Simplify the entry sequence\n• Bigger type on wayfinding\n• Warmer lighting near the lounge\n• Keep the timeline wall — everyone loved it"),
            TimelineEvent(date: date(7, 9, 11), categoryID: EventCategory.meetingID,
                          title: "Stakeholder review",
                          notes: "Approved budget increase for lighting. Asked for a contingency plan for weather.",
                          location: "HQ — Redwood Room"),
            TimelineEvent(date: date(7, 21, 9, 40), categoryID: EventCategory.emailID,
                          title: "Revised proposal sent",
                          notes: "v3 with updated floor plan and the new lighting spec."),
            TimelineEvent(date: date(7, 21, 16, 5), categoryID: EventCategory.callID,
                          title: "Follow-up with legal",
                          notes: "Venue contract needs an updated insurance certificate before signing."),
            TimelineEvent(date: date(8, 5, 13, 20), categoryID: EventCategory.purchaseID,
                          title: "Booth reservation — Design Week",
                          notes: "Corner booth, 10×20, includes power and two passes.",
                          location: "designweek.example", amount: 1200),
            TimelineEvent(date: date(8, 14, 10), categoryID: EventCategory.outingID,
                          title: "Site visit: Pier 27",
                          notes: "Measured the hall; loading dock access is from the north side only.",
                          location: "Pier 27, San Francisco"),
            TimelineEvent(date: date(8, 14, 12, 18), categoryID: EventCategory.messageID,
                          title: "Photos from the site visit",
                          notes: "Sent 24 photos and the measurements sheet to the group."),
            TimelineEvent(date: date(9, 3, 15), categoryID: EventCategory.meetingID,
                          title: "Final dry run",
                          notes: "Full walkthrough with the crew. Two small fixes on signage; otherwise ready.",
                          location: "Pier 27, San Francisco"),
            TimelineEvent(date: date(9, 12), isAllDay: true, categoryID: EventCategory.outingID,
                          title: "Launch day ✨",
                          notes: "Doors at 6 PM. 420 guests, press from three outlets, and a line out the door by 7.",
                          location: "Pier 27, San Francisco"),
            TimelineEvent(date: date(9, 14, 10), categoryID: EventCategory.noteID,
                          title: "Retrospective notes",
                          notes: "What worked: early prototyping, weekly vendor syncs. Next time: lock the venue earlier and budget more time for permits."),
        ]
        events.forEach(context.insert)
        try? context.save()
    }
}

extension SampleData {
    /// Two parallel timelines — texts and calls on one busy afternoon — to show time-synced comparison.
    /// Sets up the timeline labels too, so it presents correctly straight away.
    static func insertComparison(into context: ModelContext, replacingTitle: Bool = false) {
        let calendar = Calendar.current
        func time(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: hour, minute: minute)) ?? .now
        }

        let texts: [(Int, Int, String, String)] = [
            (12, 41, "“Truck’s here early”", "Movers arrived 20 minutes ahead of schedule."),
            (12, 55, "“Can you grab the keys?”", "Landlord’s office closes at 2."),
            (13, 3, "“Couch won’t fit the stairs”", "Sent two photos of the stairwell."),
            (13, 5, "“Calling the building now”", ""),
            (13, 41, "“Freight elevator is ours until 3”", "Building manager confirmed by text."),
            (14, 10, "“Last box on the truck”", ""),
            (14, 58, "“At the new place 🎉”", "Unloading started; pizza ordered."),
            (15, 34, "“Everything’s in. Thank you!!”", ""),
        ]
        let calls: [(Int, Int, String, String)] = [
            (12, 30, "Call with moving company", "Confirmed the crew of three and the 1 PM start."),
            (13, 0, "Call from Jordan", "Agreed to pick up the keys on the way."),
            (13, 22, "Call to building manager", "Asked about the freight elevator; they’ll check and text back."),
            (14, 5, "Call with landlord", "Walkthrough moved to Monday at 10."),
            (15, 30, "Call to Mom", "Told her it all went fine."),
        ]

        for (hour, minute, title, notes) in texts {
            context.insert(TimelineEvent(date: time(hour, minute), categoryID: EventCategory.messageID,
                                         title: title, notes: notes, laneIndex: 0))
        }
        for (hour, minute, title, notes) in calls {
            context.insert(TimelineEvent(date: time(hour, minute), categoryID: EventCategory.callID,
                                         title: title, notes: notes, laneIndex: 1))
        }
        try? context.save()
        configureLanes(["Text Messages", "Phone Calls"], title: "Moving Day",
                       subtitle: "Texts vs. calls · Saturday, October 3", replacingTitle: replacingTitle)
    }

    /// Three parallel timelines — emails, texts and meetings — across one day of closing a deal.
    /// The three streams interleave unevenly, so at each step one timeline lands on its event while
    /// the other two glide part of the way toward theirs.
    static func insertThreeTimelines(into context: ModelContext, replacingTitle: Bool = false) {
        for item in threeTimelineItems {
            context.insert(TimelineEvent(date: item.date, categoryID: item.categoryID, title: item.title,
                                         notes: item.notes, location: item.location, laneIndex: item.lane))
        }
        try? context.save()
        configureLanes(["Emails", "Text Messages", "Meetings"], title: "Closing the Northwind Deal",
                       subtitle: "Emails, texts & meetings · Thursday, November 12", replacingTitle: replacingTitle)
    }

    struct SampleItem {
        let lane: Int
        let categoryID: String
        let date: Date
        let title: String
        let notes: String
        let location: String
    }

    static let threeTimelineItems: [SampleItem] = {
        let calendar = Calendar.current
        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: hour, minute: minute)) ?? .now
        }
        func email(_ hour: Int, _ minute: Int, _ title: String, _ notes: String) -> SampleItem {
            SampleItem(lane: 0, categoryID: EventCategory.emailID, date: at(hour, minute), title: title, notes: notes, location: "")
        }
        func text(_ hour: Int, _ minute: Int, _ title: String, _ notes: String = "") -> SampleItem {
            SampleItem(lane: 1, categoryID: EventCategory.messageID, date: at(hour, minute), title: title, notes: notes, location: "")
        }
        func meeting(_ hour: Int, _ minute: Int, _ title: String, _ notes: String, _ location: String) -> SampleItem {
            SampleItem(lane: 2, categoryID: EventCategory.meetingID, date: at(hour, minute), title: title, notes: notes, location: location)
        }

        return [
            email(8, 12, "Draft term sheet from Dana", "First pass at pricing, a 3-year term and net-30 payment."),
            text(8, 34, "Sam: “Running 10 min late”", "Train stuck at Civic Center."),
            meeting(9, 0, "Morning stand-up", "Agreed the deal is today's top priority. Dana leads, Sam on pricing.", "Zoom"),
            email(9, 47, "Legal's redlines", "Clause 7 (liability cap) and clause 12 (auto-renewal) flagged."),
            text(9, 52, "Dana: “Clause 7 is a problem”", "Northwind won't accept an uncapped liability."),
            text(10, 20, "Sam: “Can you join at 10:30?”"),
            meeting(10, 30, "Pricing review with finance", "Floor set at a 12% discount for a 3-year commitment.", "Room 4B"),
            email(11, 5, "Revised pricing table", "Three tiers, with the 12% floor on the 3-year option."),
            text(12, 41, "Dana: “They want net-60”", "Their AP runs on a 60-day cycle."),
            email(13, 18, "Counter-proposal from Northwind", "Net-60, 10% discount, liability capped at 2× annual fees."),
            text(13, 25, "Sam: “Counter looks reasonable”"),
            text(14, 10, "Dana: “Coffee before the 2:30?”"),
            meeting(14, 30, "Negotiation session with Northwind", "Settled on net-45, an 11% discount and the 2× liability cap.", "Northwind HQ, 18th floor"),
            email(15, 2, "Agreement v4", "All negotiated terms in; legal approved within the hour."),
            meeting(16, 0, "Final terms walkthrough", "Line-by-line read-through with both legal teams.", "Video call"),
            email(16, 40, "Signed contract", "Northwind signed; countersignature requested."),
            text(16, 44, "Sam: “🎉 It's signed!”"),
            meeting(17, 30, "Team debrief", "What worked: fast pricing approvals. Next time: involve legal earlier.", "Room 4B"),
            email(17, 55, "Thank-you note to the Northwind team", "Kickoff proposed for the first week of December."),
            text(18, 2, "Dana: “Dinner at 7 to celebrate?”"),
        ]
    }()

    /// Turns on the sample's timelines and labels. The title is only replaced when asked, or when it's still the default.
    private static func configureLanes(_ labels: [String], title: String, subtitle: String, replacingTitle: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(labels.count, forKey: PrefKey.laneCount)
        defaults.set(Lanes.encodedOrder(Array(labels.indices)), forKey: PrefKey.laneOrder)
        for (index, label) in labels.enumerated() {
            defaults.set(label, forKey: PrefKey.laneLabel(index))
        }
        let current = defaults.string(forKey: PrefKey.title) ?? ""
        if replacingTitle || current.isEmpty || current == TimelineDefaults.title {
            defaults.set(title, forKey: PrefKey.title)
            defaults.set(subtitle, forKey: PrefKey.subtitle)
        }
    }
}

/// The ready-made multi-timeline examples offered in the Timeline menu.
enum SampleSet: String, Identifiable {
    case comparison, threeTimelines

    var id: String { rawValue }

    var title: String {
        switch self {
        case .comparison: "Load the texts-vs-calls sample?"
        case .threeTimelines: "Load the three-timeline sample?"
        }
    }
}
