import Foundation

struct ImportCandidate: Identifiable {
    enum Status { case ready, warning, error }

    let id: Int
    var rawDate: String
    var date: Date?
    var isAllDay: Bool
    var title: String
    var notes: String
    var categoryID: String?
    var rawType: String
    var location: String
    var amount: Double?
    /// Timeline name from the file, before it is matched to a lane.
    var rawLane: String
    var laneIndex: Int?
    var issues: [String]
    var include: Bool

    var status: Status {
        if date == nil || title.isEmpty { return .error }
        return issues.isEmpty ? .ready : .warning
    }
}

struct ImportAnalysis: Identifiable {
    let id = UUID()
    let fileName: String
    var candidates: [ImportCandidate]
    let detectedColumns: [String]
    let hasTypeColumn: Bool
    /// Distinct timeline names from the file, in the order they first appear.
    let timelineNames: [String]
}

/// How an import should treat the timeline names it found.
struct ImportLanePlan {
    /// When set, the window's timelines are renamed to these, in order. The count becomes this list's length.
    var laneNames: [String]?
    /// Removes the events already in the window before the new rows are added. Dividers stay.
    var replaceExisting: Bool
}

enum CSVImportError: LocalizedError {
    case unreadable
    case empty
    case missingDateColumn(found: [String])

    var errorDescription: String? {
        switch self {
        case .unreadable:
            "The file couldn’t be read as text."
        case .empty:
            "The file doesn’t contain any event rows."
        case .missingDateColumn(let found):
            "No date column was found. Timeline Studio looks for headers like “date”, “description” and “notes”."
                + (found.isEmpty ? "" : " Found: \(found.prefix(8).joined(separator: ", ")).")
        }
    }
}

enum CSVImporter {
    enum Field: String, CaseIterable {
        case date, time, title, notes, type, location, amount, lane

        var aliases: [String] {
            switch self {
            case .date: ["date", "datetime", "timestamp", "when", "day", "eventdate", "startdate", "start", "dateandtime", "sentdate"]
            case .time: ["time", "starttime", "eventtime", "hour"]
            case .title: ["description", "title", "event", "summary", "name", "subject", "eventname", "what", "desc"]
            case .notes: ["notes", "note", "details", "comments", "comment", "body", "memo", "message", "content"]
            case .type: ["type", "category", "kind", "eventtype", "channel", "source"]
            case .location: ["location", "place", "where", "venue", "address", "merchant", "store"]
            case .amount: ["amount", "price", "cost", "total", "value", "spent"]
            case .lane: ["timeline", "lane", "track", "sequence", "stream", "group"]
            }
        }

        var label: String {
            switch self {
            case .title: "description"
            case .lane: "timeline"
            default: rawValue
            }
        }
    }

    static func readText(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
           let text = String(data: data, encoding: .utf16) {
            return text
        }
        for encoding in [String.Encoding.utf8, .windowsCP1252, .isoLatin1] {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        throw CSVImportError.unreadable
    }

    static func analyze(text: String, fileName: String, catalog: CategoryCatalog,
                        laneLabels: [String] = []) throws -> ImportAnalysis {
        let rows = CSVParser.parse(text)
        guard let header = rows.first else { throw CSVImportError.empty }

        var mapping = headerMapping(for: header)
        var dataRows = Array(rows.dropFirst())
        var firstLine = 2

        if mapping[.date] == nil {
            // Headerless file: assume date, description, notes, type order if the first cell looks like a date.
            guard FlexibleDateParser.parse(header.first ?? "") != nil else {
                throw CSVImportError.missingDateColumn(found: header)
            }
            mapping = [.date: 0, .title: 1, .notes: 2, .type: 3]
            dataRows = rows
            firstLine = 1
        }
        guard !dataRows.isEmpty else { throw CSVImportError.empty }

        var candidates = dataRows.enumerated().map { offset, row in
            makeCandidate(row: row, line: offset + firstLine, mapping: mapping, catalog: catalog, laneLabels: laneLabels)
        }
        let timelineNames = distinctTimelineNames(in: candidates)
        let detected = Field.allCases.filter { mapping[$0] != nil }.map(\.label)
        return ImportAnalysis(fileName: fileName, candidates: candidates,
                              detectedColumns: detected, hasTypeColumn: mapping[.type] != nil,
                              timelineNames: timelineNames)
    }

    /// First spelling wins. "Maya" and "maya" are one timeline.
    static func distinctTimelineNames(in candidates: [ImportCandidate]) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for candidate in candidates {
            let trimmed = candidate.rawLane.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = CategoryCatalog.normalize(trimmed)
            guard seen.insert(key).inserted else { continue }
            names.append(trimmed)
        }
        return names
    }

    private static func headerMapping(for header: [String]) -> [Field: Int] {
        var mapping: [Field: Int] = [:]
        for (index, title) in header.enumerated() {
            let key = CategoryCatalog.normalize(title)
            if let field = Field.allCases.first(where: { mapping[$0] == nil && $0.aliases.contains(key) }) {
                mapping[field] = index
            }
        }
        return mapping
    }

    private static func makeCandidate(row: [String], line: Int, mapping: [Field: Int], catalog: CategoryCatalog,
                                      laneLabels: [String]) -> ImportCandidate {
        func cell(_ field: Field) -> String {
            guard let index = mapping[field], index < row.count else { return "" }
            return row[index]
        }

        var issues: [String] = []

        let rawDate = cell(.date)
        let rawTime = cell(.time)
        let parsed = FlexibleDateParser.parse(rawDate, time: rawTime.isEmpty ? nil : rawTime)
        if rawDate.isEmpty {
            issues.append("Missing date")
        } else if parsed == nil {
            issues.append("Couldn’t understand the date “\(rawDate)”")
        }

        var title = cell(.title)
        let notes = cell(.notes)
        if title.isEmpty, !notes.isEmpty {
            let firstLine = notes.split(whereSeparator: \.isNewline).first.map(String.init) ?? notes
            title = firstLine.count > 60 ? String(firstLine.prefix(57)) + "…" : firstLine
            issues.append("No description — used the start of the notes")
        }
        if title.isEmpty { issues.append("Missing description") }

        let rawType = cell(.type)
        var categoryID: String?
        if !rawType.isEmpty {
            if let match = catalog.match(rawType) {
                categoryID = match.id
            } else {
                issues.append("Unknown type “\(rawType)” — the default type will be used")
            }
        }

        let rawAmount = cell(.amount)
        var amount: Double?
        if !rawAmount.isEmpty {
            amount = parseAmount(rawAmount)
            if amount == nil { issues.append("Ignored amount “\(rawAmount)”") }
        }

        let rawLane = cell(.lane).trimmingCharacters(in: .whitespacesAndNewlines)
        var laneIndex: Int?
        if !rawLane.isEmpty, !laneLabels.isEmpty {
            laneIndex = matchLane(rawLane, labels: laneLabels)
        }

        let isValid = parsed != nil && !title.isEmpty
        return ImportCandidate(
            id: line, rawDate: rawDate, date: parsed?.date, isAllDay: !(parsed?.hasTime ?? false),
            title: title, notes: notes, categoryID: categoryID, rawType: rawType,
            location: cell(.location), amount: amount, rawLane: rawLane, laneIndex: laneIndex,
            issues: issues, include: isValid)
    }

    /// Matches a timeline by its label ("Phone Calls") or its number ("2").
    static func matchLane(_ raw: String, labels: [String]) -> Int? {
        let key = CategoryCatalog.normalize(raw)
        if let index = labels.firstIndex(where: { CategoryCatalog.normalize($0) == key }) { return index }
        if let number = Int(key), (1...labels.count).contains(number) { return number - 1 }
        return nil
    }

    static func parseAmount(_ raw: String) -> Double? {
        let negative = raw.contains("(") && raw.contains(")")
        let cleaned = raw.filter { "0123456789.-".contains($0) }
        guard let value = Double(cleaned) else { return nil }
        return negative ? -abs(value) : value
    }
}
