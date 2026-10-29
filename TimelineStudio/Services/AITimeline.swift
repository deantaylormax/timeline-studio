import Foundation
import SwiftData

struct AIEventPatch {
    var date: Date?
    var isAllDay: Bool?
    var categoryID: String?
    var title: String?
    var notes: String?
    var location: String?
    var laneIndex: Int?
}

struct AIProposedEvent: Identifiable {
    let id = UUID()
    var date: Date
    var isAllDay: Bool
    var categoryID: String
    var title: String
    var notes: String
    var location: String
    var laneIndex: Int
}

struct AIDescribedChange: Identifiable {
    let id = UUID()
    var eventID: UUID
    var headline: String
    var detail: String
    var patch: AIEventPatch
    var delete: Bool
}

struct AIProposal {
    var summary: String
    var adds: [AIProposedEvent]
    var changes: [AIDescribedChange]
    var skipped: [String]
}

struct AIFinding: Identifiable {
    let id = UUID()
    var kind: String
    var title: String
    var detail: String
}

struct AINarrative {
    var title: String
    var body: String
}

struct AIResultLink: Identifiable, Equatable {
    var id: UUID
    var title: String
}

/// The line shown after a request, plus a link for each event the user can open.
struct AIResultNotice: Equatable {
    var message: String
    var links: [AIResultLink]
    var detail: String
    var didChange: Bool

    init(summary: String, added: [TimelineEvent], updated: [TimelineEvent], removedTitles: [String], skipped: [String], catalog: CategoryCatalog) {
        var parts: [String] = []
        if added.count == 1, let event = added.first {
            parts.append("Added \(Self.named(event, catalog: catalog)).")
        } else if added.count > 1 {
            parts.append("Added \(added.count) events.")
        }
        if updated.count == 1, let event = updated.first {
            parts.append("Updated \(Self.named(event, catalog: catalog)).")
        } else if updated.count > 1 {
            parts.append("Updated \(updated.count) events.")
        }
        if removedTitles.count == 1, let title = removedTitles.first {
            parts.append("Removed “\(title)”.")
        } else if removedTitles.count > 1 {
            parts.append("Removed \(removedTitles.count) events.")
        }
        let changed = !parts.isEmpty
        message = changed ? parts.joined(separator: " ") : (summary.isEmpty ? "Nothing changed." : summary)
        links = (added + updated).map { event in
            AIResultLink(id: event.id, title: event.title.isEmpty ? "Untitled event" : event.title)
        }
        let extra = [changed ? summary : "", skipped.joined(separator: " ")]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        detail = extra.joined(separator: " ")
        didChange = changed
    }

    private static func named(_ event: TimelineEvent, catalog: CategoryCatalog) -> String {
        let title = event.title.isEmpty ? "Untitled event" : event.title
        let category = catalog.category(for: event.categoryID).name
        return "\(category) “\(title)”"
    }
}

enum AITimeline {
    static let eventLimit = 160
    static let documentLimit = 20_000

    static func editRequest(
        instruction: String,
        events: [TimelineEvent],
        dividers: [TimelineDivider],
        catalog: CategoryCatalog,
        lanes: [(index: Int, name: String)]
    ) -> (system: String, user: String, sent: Int, total: Int) {
        let packed = pack(events: events, dividers: dividers, catalog: catalog, lanes: lanes)
        let system = """
        You edit one legal chronology. Reply with JSON only, no markdown.
        Schema: {"summary":"string","operations":[{"op":"add","date":"ISO-8601","allDay":false,"lane":1,"category":"id","title":"","notes":"","location":""},{"op":"update","id":"uuid","title":""},{"op":"delete","id":"uuid"}]}
        Lane numbers and category ids must come from the list below. update and delete must use an id from the timeline. add must not include an id.
        Change only what the instruction asks. If nothing should change, return an empty operations array.
        """
        let user = """
        \(packed.text)
        Instruction: \(instruction)
        """
        return (system, user, packed.sent, packed.total)
    }

    static func extractRequest(
        documentName: String,
        documentText: String,
        focus: String,
        catalog: CategoryCatalog,
        lanes: [(index: Int, name: String)]
    ) -> (system: String, user: String, truncated: Bool) {
        let truncated = documentText.count > documentLimit
        let body = truncated ? String(documentText.prefix(documentLimit)) : documentText
        let system = """
        Extract dated events from a source document. Reply with JSON only, no markdown.
        Schema: {"summary":"string","events":[{"date":"ISO-8601","allDay":false,"lane":1,"category":"id","title":"","notes":"","location":"","citation":"p. 4"}]}
        Use only dates written in the document. Put the page or location in citation. category and lane must come from the lists. Skip undated material.
        """
        var user = "\(contextHeader(catalog: catalog, lanes: lanes))\nDocument: \(documentName)\n"
        if truncated { user += "The document was truncated to \(documentLimit) characters.\n" }
        if !focus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            user += "Focus: \(focus)\n"
        }
        user += body
        return (system, user, truncated)
    }

    static func reviewRequest(
        events: [TimelineEvent],
        dividers: [TimelineDivider],
        catalog: CategoryCatalog,
        lanes: [(index: Int, name: String)]
    ) -> (system: String, user: String, sent: Int, total: Int) {
        let packed = pack(events: events, dividers: dividers, catalog: catalog, lanes: lanes)
        let system = """
        Review one chronology for contradictions, gaps, and impossible sequences. Reply with JSON only, no markdown.
        Schema: {"findings":[{"kind":"contradiction","title":"","detail":"","eventIDs":["uuid"]}]}
        kind is contradiction, gap, or impossible. Quote the timeline. Do not invent events. If you find nothing, return an empty findings array.
        """
        return (system, packed.text, packed.sent, packed.total)
    }

    static func narrativeRequest(
        events: [TimelineEvent],
        dividers: [TimelineDivider],
        catalog: CategoryCatalog,
        lanes: [(index: Int, name: String)]
    ) -> (system: String, user: String, sent: Int, total: Int) {
        let packed = pack(events: events, dividers: dividers, catalog: catalog, lanes: lanes)
        let system = """
        Write a chronology memo a lawyer can edit. Reply with JSON only, no markdown.
        Schema: {"title":"string","body":"string"}
        Cite events by their date and title. Plain paragraphs.
        """
        return (system, packed.text, packed.sent, packed.total)
    }

    static func parseEdits(
        _ text: String,
        events: [TimelineEvent],
        catalog: CategoryCatalog,
        laneCount: Int
    ) throws -> AIProposal {
        let object = try jsonObject(text)
        let summary = object["summary"] as? String ?? ""
        let operations = object["operations"] as? [[String: Any]] ?? []
        var proposal = AIProposal(summary: summary, adds: [], changes: [], skipped: [])
        for operation in operations.prefix(100) {
            let op = (operation["op"] as? String ?? "").lowercased()
            switch op {
            case "add":
                if let proposed = proposedEvent(operation, catalog: catalog, laneCount: laneCount) {
                    proposal.adds.append(proposed)
                } else {
                    proposal.skipped.append("Skipped an add with no usable date or title.")
                }
            case "update":
                guard let id = uuid(operation["id"]), let event = events.first(where: { $0.id == id }) else {
                    proposal.skipped.append("Skipped an update for an unknown event.")
                    continue
                }
                let patch = patch(operation, catalog: catalog, laneCount: laneCount)
                proposal.changes.append(AIDescribedChange(
                    eventID: id,
                    headline: event.title.isEmpty ? "Untitled event" : event.title,
                    detail: describe(patch, event: event, catalog: catalog),
                    patch: patch,
                    delete: false))
            case "delete":
                guard let id = uuid(operation["id"]), let event = events.first(where: { $0.id == id }) else {
                    proposal.skipped.append("Skipped a delete for an unknown event.")
                    continue
                }
                proposal.changes.append(AIDescribedChange(
                    eventID: id,
                    headline: event.title.isEmpty ? "Untitled event" : event.title,
                    detail: "Delete this event.",
                    patch: AIEventPatch(),
                    delete: true))
            default:
                proposal.skipped.append("Skipped an unknown operation.")
            }
        }
        return proposal
    }

    static func parseExtraction(
        _ text: String,
        catalog: CategoryCatalog,
        laneCount: Int
    ) throws -> AIProposal {
        let object = try jsonObject(text)
        let summary = object["summary"] as? String ?? ""
        let rows = object["events"] as? [[String: Any]] ?? []
        var proposal = AIProposal(summary: summary, adds: [], changes: [], skipped: [])
        for row in rows.prefix(100) {
            var notes = string(row["notes"])
            let citation = string(row["citation"])
            if !citation.isEmpty {
                notes = notes.isEmpty ? "Source: \(citation)" : "\(notes)\nSource: \(citation)"
            }
            var copy = row
            copy["notes"] = notes
            if let proposed = proposedEvent(copy, catalog: catalog, laneCount: laneCount) {
                proposal.adds.append(proposed)
            } else {
                proposal.skipped.append("Skipped an item with no usable date or title.")
            }
        }
        return proposal
    }

    static func parseFindings(_ text: String) throws -> [AIFinding] {
        let object = try jsonObject(text)
        let rows = object["findings"] as? [[String: Any]] ?? []
        return rows.prefix(40).map { row in
            let kind = (row["kind"] as? String ?? "note").lowercased()
            let title = string(row["title"])
            return AIFinding(
                kind: kind.isEmpty ? "note" : kind,
                title: title.isEmpty ? "Finding" : title,
                detail: string(row["detail"]))
        }
    }

    static func parseNarrative(_ text: String) throws -> AINarrative {
        let object = try jsonObject(text)
        let title = string(object["title"])
        let body = string(object["body"])
        guard !body.isEmpty else { throw AIClientError.unreadable }
        return AINarrative(title: title.isEmpty ? "Chronology" : title, body: body)
    }

    /// Applies the proposal and returns the confirmation the window shows. Added and updated events keep a link.
    @MainActor
    static func apply(_ proposal: AIProposal, context: ModelContext, events: [TimelineEvent], catalog: CategoryCatalog) -> AIResultNotice {
        let undo = context.undoManager
        undo?.beginUndoGrouping()
        undo?.setActionName("AI Timeline Edit")
        var added: [TimelineEvent] = []
        var updated: [TimelineEvent] = []
        var removed: [String] = []
        for proposed in proposal.adds {
            let event = TimelineEvent(
                date: proposed.date,
                isAllDay: proposed.isAllDay,
                categoryID: proposed.categoryID,
                title: proposed.title,
                notes: proposed.notes,
                location: proposed.location,
                laneIndex: proposed.laneIndex)
            context.insert(event)
            added.append(event)
        }
        for change in proposal.changes {
            guard let event = events.first(where: { $0.id == change.eventID }) else { continue }
            if change.delete {
                removed.append(event.title.isEmpty ? "Untitled event" : event.title)
                context.delete(event)
                continue
            }
            let patch = change.patch
            if let date = patch.date { event.date = date }
            if let isAllDay = patch.isAllDay { event.isAllDay = isAllDay }
            if let categoryID = patch.categoryID { event.categoryID = categoryID }
            if let title = patch.title { event.title = title }
            if let notes = patch.notes { event.notes = notes }
            if let location = patch.location { event.location = location }
            if let lane = patch.laneIndex { event.laneIndex = lane }
            updated.append(event)
        }
        context.processPendingChanges()
        undo?.endUndoGrouping()
        return AIResultNotice(summary: proposal.summary, added: added, updated: updated, removedTitles: removed, skipped: proposal.skipped, catalog: catalog)
    }

    private struct Packed {
        var text: String
        var sent: Int
        var total: Int
    }

    private static func pack(
        events: [TimelineEvent],
        dividers: [TimelineDivider],
        catalog: CategoryCatalog,
        lanes: [(index: Int, name: String)]
    ) -> Packed {
        let ordered = events.sorted { $0.date < $1.date }
        let sent = Array(ordered.prefix(eventLimit))
        var lines = [contextHeader(catalog: catalog, lanes: lanes)]
        if ordered.count > sent.count {
            lines.append("The timeline has \(ordered.count) events. The first \(sent.count) by date are included.")
        }
        if !dividers.isEmpty {
            lines.append("Dividers (read only):")
            for divider in dividers.sorted(by: { $0.date < $1.date }) {
                lines.append("- \(iso(divider.date)) \(divider.displayTitle)")
            }
        }
        lines.append("Events:")
        for event in sent {
            let category = catalog.category(for: event.categoryID)
            let notes = clip(event.notes, 180)
            let record: [String: Any] = [
                "id": event.id.uuidString,
                "date": iso(event.date),
                "allDay": event.isAllDay,
                "lane": event.laneIndex + 1,
                "category": category.id,
                "title": event.title,
                "location": event.location,
                "notes": notes,
            ]
            if let data = try? JSONSerialization.data(withJSONObject: record),
               let line = String(data: data, encoding: .utf8) {
                lines.append(line)
            }
        }
        return Packed(text: lines.joined(separator: "\n"), sent: sent.count, total: ordered.count)
    }

    private static func contextHeader(catalog: CategoryCatalog, lanes: [(index: Int, name: String)]) -> String {
        let categories = catalog.all.map { "\($0.id) (\($0.name))" }.joined(separator: ", ")
        let laneLine = lanes.map { "\($0.index + 1) (\($0.name))" }.joined(separator: ", ")
        return "Categories: \(categories)\nLanes: \(laneLine)"
    }

    private static func proposedEvent(
        _ row: [String: Any],
        catalog: CategoryCatalog,
        laneCount: Int
    ) -> AIProposedEvent? {
        guard let parsed = parseDate(string(row["date"])) else { return nil }
        let title = string(row["title"])
        guard !title.isEmpty else { return nil }
        let allDay = (row["allDay"] as? Bool) ?? !parsed.hasTime
        return AIProposedEvent(
            date: parsed.date,
            isAllDay: allDay,
            categoryID: categoryID(string(row["category"]), catalog: catalog),
            title: title,
            notes: string(row["notes"]),
            location: string(row["location"]),
            laneIndex: laneIndex(row["lane"], count: laneCount))
    }

    private static func patch(_ row: [String: Any], catalog: CategoryCatalog, laneCount: Int) -> AIEventPatch {
        var patch = AIEventPatch()
        if let parsed = parseDate(string(row["date"])) {
            patch.date = parsed.date
            patch.isAllDay = (row["allDay"] as? Bool) ?? !parsed.hasTime
        } else if let allDay = row["allDay"] as? Bool {
            patch.isAllDay = allDay
        }
        let category = string(row["category"])
        if !category.isEmpty { patch.categoryID = categoryID(category, catalog: catalog) }
        if row["title"] != nil { patch.title = string(row["title"]) }
        if row["notes"] != nil { patch.notes = string(row["notes"]) }
        if row["location"] != nil { patch.location = string(row["location"]) }
        if row["lane"] != nil { patch.laneIndex = laneIndex(row["lane"], count: laneCount) }
        return patch
    }

    private static func describe(_ patch: AIEventPatch, event: TimelineEvent, catalog: CategoryCatalog) -> String {
        var parts: [String] = []
        if let title = patch.title, title != event.title { parts.append("Title → \(title)") }
        if let date = patch.date, date != event.date {
            parts.append("Date → \(date.formatted(date: .abbreviated, time: .shortened))")
        }
        if let categoryID = patch.categoryID, categoryID != event.categoryID {
            parts.append("Type → \(catalog.category(for: categoryID).name)")
        }
        if let lane = patch.laneIndex, lane != event.laneIndex { parts.append("Timeline → \(lane + 1)") }
        if let location = patch.location, location != event.location { parts.append("Location → \(location)") }
        if let notes = patch.notes, notes != event.notes { parts.append("Notes updated") }
        if let allDay = patch.isAllDay, allDay != event.isAllDay {
            parts.append(allDay ? "All day" : "Timed")
        }
        return parts.isEmpty ? "No visible change." : parts.joined(separator: " · ")
    }

    private static func categoryID(_ raw: String, catalog: CategoryCatalog) -> String {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let match = catalog.all.first(where: { $0.id.lowercased() == key || $0.name.lowercased() == key }) {
            return match.id
        }
        if let match = catalog.all.first(where: { category in
            category.keywords.contains { keyword in key == keyword || key.contains(keyword) }
        }) {
            return match.id
        }
        return EventCategory.noteID
    }

    private static func laneIndex(_ value: Any?, count: Int) -> Int {
        let number: Int
        if let int = value as? Int {
            number = int
        } else if let string = value as? String, let int = Int(string) {
            number = int
        } else {
            number = 1
        }
        let index = number >= 1 ? number - 1 : 0
        return min(max(index, 0), max(count, 1) - 1)
    }

    private static func parseDate(_ raw: String) -> FlexibleDateParser.Result? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return FlexibleDateParser.parse(trimmed)
    }

    private static func uuid(_ value: Any?) -> UUID? {
        guard let string = value as? String else { return nil }
        return UUID(uuidString: string)
    }

    private static func string(_ value: Any?) -> String {
        if let string = value as? String { return string.trimmingCharacters(in: .whitespacesAndNewlines) }
        return ""
    }

    private static func clip(_ text: String, _ limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit))
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func jsonObject(_ text: String) throws -> [String: Any] {
        var raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") {
            raw = String(raw[start...end])
        }
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIClientError.unreadable
        }
        return object
    }
}
