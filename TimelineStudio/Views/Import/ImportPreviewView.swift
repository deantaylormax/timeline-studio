import SwiftUI

private enum ImportTimelineChoice: String, CaseIterable, Identifiable {
    case useFile, map, single
    var id: String { rawValue }
}

struct ImportPreviewView: View {
    let fileName: String
    let detectedColumns: [String]
    let hasTypeColumn: Bool
    let timelineNames: [String]
    let existingEventCount: Int
    let onImport: ([ImportCandidate], String, Int, ImportLanePlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.categoryCatalog) private var catalog
    @State private var candidates: [ImportCandidate]
    @State private var defaultCategoryID = EventCategory.noteID
    @State private var defaultLane = 0
    @State private var choice: ImportTimelineChoice
    @State private var mapping: [String: Int]
    @State private var replaceExisting = false
    private var lanes = LaneSettings()

    init(analysis: ImportAnalysis, existingEventCount: Int = 0,
         onImport: @escaping ([ImportCandidate], String, Int, ImportLanePlan) -> Void) {
        fileName = analysis.fileName
        detectedColumns = analysis.detectedColumns
        hasTypeColumn = analysis.hasTypeColumn
        timelineNames = analysis.timelineNames
        self.existingEventCount = existingEventCount
        self.onImport = onImport
        _candidates = State(initialValue: analysis.candidates)

        let openCount = min(max(UserDefaults.standard.integer(forKey: PrefKey.laneCount), 1), Lanes.maxCount)
        let openLabels = (0..<openCount).map { index -> String in
            let stored = UserDefaults.standard.string(forKey: PrefKey.laneLabel(index)) ?? ""
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? Lanes.defaultLabel(index) : trimmed
        }
        var initialMap: [String: Int] = [:]
        for (offset, name) in analysis.timelineNames.enumerated() {
            let key = CategoryCatalog.normalize(name)
            if let match = CSVImporter.matchLane(name, labels: openLabels) {
                initialMap[key] = match
            } else {
                initialMap[key] = min(offset, openCount - 1)
            }
        }
        _mapping = State(initialValue: initialMap)
        _choice = State(initialValue: .useFile)
    }

    private var importableCount: Int { candidates.filter { $0.include && $0.status != .error }.count }
    private var warningCount: Int { candidates.filter { $0.status == .warning }.count }
    private var errorCount: Int { candidates.filter { $0.status == .error }.count }
    private var readyCount: Int { candidates.filter { $0.status == .ready }.count }
    private var needsDefaultType: Bool { candidates.contains { $0.categoryID == nil && $0.status != .error } }
    private var showsTimelinePrompt: Bool { timelineNames.count >= 2 }
    /// One, two, or three names from the file become the window's timeline names, unless a multi-timeline file is mapped by hand.
    private var appliesFileNames: Bool {
        if timelineNames.isEmpty { return false }
        if timelineNames.count == 1 { return true }
        return choice == .useFile
    }
    private var hasBlankTimeline: Bool {
        candidates.contains {
            $0.status != .error && $0.rawLane.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    private var needsDefaultLane: Bool {
        if timelineNames.count == 1 { return false }
        if showsTimelinePrompt { return choice == .map && hasBlankTimeline }
        return lanes.isMultiLane && candidates.contains { $0.laneIndex == nil && $0.status != .error }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if timelineNames.count == 1 {
                singleNameNote
                Divider()
            } else if showsTimelinePrompt {
                timelinePrompt
                Divider()
            }
            options
            table
            Divider()
            footer
        }
        .frame(width: 920, height: showsTimelinePrompt ? 720 : (timelineNames.count == 1 ? 640 : 600))
    }

    private var header: some View {
        HStack(spacing: 14) {
            IconTile(symbol: "tablecells", color: .green, size: 44, rounded: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Import Preview")
                    .font(.system(size: 17, weight: .semibold))
                Text(fileName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            SummaryPill(count: readyCount, label: "ready", symbol: "checkmark.circle.fill", color: .green)
            if warningCount > 0 {
                SummaryPill(count: warningCount, label: warningCount == 1 ? "warning" : "warnings",
                            symbol: "exclamationmark.triangle.fill", color: .orange)
            }
            if errorCount > 0 {
                SummaryPill(count: errorCount, label: "skipped", symbol: "xmark.octagon.fill", color: .red)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var singleNameNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This file has 1 timeline: \(timelineNames[0]). The window will use that name.")
                .font(.system(size: 13, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            if existingEventCount > 0 && !replaceExisting {
                Text("Events already here stay in the window.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            if existingEventCount > 0 {
                Toggle("Replace the events already in the window", isOn: $replaceExisting)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
    }

    private var timelinePrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(promptTitle)
                .font(.system(size: 13, weight: .semibold))
            if let overflow = overflowNote {
                Text(overflow)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                choiceRow(.useFile, title: "Use these timelines")
                choiceRow(.map, title: lanes.count == 1
                          ? "Map them onto the timeline already open"
                          : "Map them onto the timelines already open")
                choiceRow(.single, title: "Put every row on one timeline")
            }
            if existingEventCount > 0 {
                Toggle("Replace the events already in the window", isOn: $replaceExisting)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
    }

    private func choiceRow(_ option: ImportTimelineChoice, title: String) -> some View {
        let isSelected = choice == option
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                choice = option
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            if isSelected {
                choiceDetail(option)
                    .padding(.leading, 21)
            }
        }
    }

    @ViewBuilder
    private func choiceDetail(_ option: ImportTimelineChoice) -> some View {
        switch option {
        case .useFile:
            Text(useFileNote)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .map:
            if timelineNames.count > 4 {
                ScrollView { mapPickers }
                    .frame(height: 150)
            } else {
                mapPickers
            }
        case .single:
            HStack(spacing: 10) {
                Text("Timeline")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                lanePicker
            }
        }
    }

    private var mapPickers: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(timelineNames, id: \.self) { name in
                HStack(spacing: 10) {
                    Text(name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .frame(width: 140, alignment: .leading)
                    Picker(name, selection: mappingBinding(for: name)) {
                        ForEach(lanes.order, id: \.self) { lane in
                            Text(lanes.label(lane)).tag(lane)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
            }
            if hasBlankTimeline {
                HStack(spacing: 10) {
                    Text("No timeline in the row")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 140, alignment: .leading)
                    lanePicker
                }
            }
        }
    }

    private var lanePicker: some View {
        Picker("Timeline", selection: $defaultLane) {
            ForEach(lanes.order, id: \.self) { lane in
                Text(lanes.label(lane)).tag(lane)
            }
        }
        .labelsHidden()
        .frame(width: 180)
    }

    private var promptTitle: String {
        let count = timelineNames.count
        if count > Lanes.maxCount {
            return "This file names \(count) timelines. A window holds three."
        }
        return "This file has \(count) timelines: \(listed(timelineNames))."
    }

    private var overflowNote: String? {
        guard timelineNames.count > Lanes.maxCount else { return nil }
        let kept = Array(timelineNames.prefix(Lanes.maxCount))
        return "\(listed(kept)) each get a timeline. The rest go on \(kept[kept.count - 1])."
    }

    private var useFileNote: String {
        let kept = Array(timelineNames.prefix(Lanes.maxCount))
        let countWord = kept.count == 1 ? "1 timeline" : "\(kept.count) timelines"
        var note = "The window will show \(countWord) named \(listed(kept))."
        if existingEventCount > 0 && !replaceExisting {
            note += " Events already here stay on their lanes and take these names."
        }
        return note
    }

    private var options: some View {
        HStack(spacing: 10) {
            if needsDefaultType {
                Text(hasTypeColumn ? "Rows with no recognized type:" : "Import all rows as:")
                    .font(.system(size: 12))
                Picker("Default type", selection: $defaultCategoryID) {
                    ForEach(catalog.all) { category in
                        Label(category.name, systemImage: category.symbol).tag(category.id)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            if needsDefaultLane && !showsTimelinePrompt {
                Text(needsDefaultType ? "on" : "Add rows without a timeline to:")
                    .font(.system(size: 12))
                lanePicker
            }
            Spacer()
            Text("Columns found: \(detectedColumns.joined(separator: ", "))")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
    }

    private var table: some View {
        Table(candidates) {
            TableColumn("") { (candidate: ImportCandidate) in
                Toggle("Include", isOn: includeBinding(for: candidate.id))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .disabled(candidate.status == .error)
            }
            .width(22)

            TableColumn("") { (candidate: ImportCandidate) in
                statusIcon(for: candidate)
            }
            .width(22)

            TableColumn("Row") { (candidate: ImportCandidate) in
                Text("\(candidate.id)")
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            .width(34)

            TableColumn("Date") { (candidate: ImportCandidate) in
                if let date = candidate.date {
                    Text(date.formatted(date: .abbreviated, time: candidate.isAllDay ? .omitted : .shortened))
                        .monospacedDigit()
                } else {
                    Text(candidate.rawDate.isEmpty ? "Missing" : candidate.rawDate)
                        .foregroundStyle(.red)
                }
            }
            .width(min: 120, ideal: 160)

            TableColumn("Type") { (candidate: ImportCandidate) in
                let category = catalog.category(for: candidate.categoryID ?? defaultCategoryID)
                HStack(spacing: 6) {
                    CategoryBadge(category: category, size: 18, rounded: true)
                    Text(category.name)
                        .foregroundStyle(candidate.categoryID == nil ? .secondary : .primary)
                }
            }
            .width(min: 110, ideal: 130)

            TableColumn("Timeline") { (candidate: ImportCandidate) in
                let index = laneIndex(for: candidate)
                let assigned = timelineIsAssigned(candidate)
                HStack(spacing: 6) {
                    Circle().fill(Lanes.tints[index].gradient).frame(width: 8, height: 8)
                    Text(destinationName(for: candidate, index: index))
                        .foregroundStyle(assigned ? .primary : .secondary)
                        .lineLimit(1)
                }
            }
            .width(min: 110, ideal: 140)
            .defaultVisibility((!timelineNames.isEmpty || lanes.isMultiLane) ? .visible : .hidden)

            TableColumn("Description") { (candidate: ImportCandidate) in
                Text(candidate.title.isEmpty ? "—" : candidate.title)
                    .lineLimit(1)
            }
            .width(min: 160, ideal: 230)

            TableColumn("Notes") { (candidate: ImportCandidate) in
                Text(candidate.notes)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if errorCount > 0 || warningCount > 0 {
                Label("Hover a status icon to see what’s wrong with a row.", systemImage: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(importableCount == 1 ? "Import 1 Event" : "Import \(importableCount) Events") {
                onImport(resolvedCandidates(), defaultCategoryID, defaultLane, plan)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(importableCount == 0)
        }
        .controlSize(.large)
        .padding(16)
    }

    private var plan: ImportLanePlan {
        let names = appliesFileNames ? Array(timelineNames.prefix(Lanes.maxCount)) : nil
        return ImportLanePlan(laneNames: names, replaceExisting: replaceExisting && existingEventCount > 0)
    }

    private func resolvedCandidates() -> [ImportCandidate] {
        candidates.map { candidate in
            var copy = candidate
            copy.laneIndex = laneIndex(for: candidate)
            return copy
        }
    }

    /// Where this row will land once the choice above is applied.
    private func laneIndex(for candidate: ImportCandidate) -> Int {
        let visible = max(lanes.count, 1)
        if timelineNames.count == 1 { return 0 }
        if !showsTimelinePrompt {
            return min(max(candidate.laneIndex ?? defaultLane, 0), visible - 1)
        }
        switch choice {
        case .useFile:
            return fileLaneIndex(candidate.rawLane)
        case .map:
            if candidate.rawLane.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return min(max(defaultLane, 0), visible - 1)
            }
            let key = CategoryCatalog.normalize(candidate.rawLane)
            return min(max(mapping[key] ?? defaultLane, 0), visible - 1)
        case .single:
            return min(max(defaultLane, 0), visible - 1)
        }
    }

    private func fileLaneIndex(_ raw: String) -> Int {
        let limit = min(max(timelineNames.count, 1), Lanes.maxCount)
        let key = CategoryCatalog.normalize(raw)
        guard !key.isEmpty,
              let index = timelineNames.firstIndex(where: { CategoryCatalog.normalize($0) == key })
        else { return 0 }
        return min(index, limit - 1)
    }

    private func destinationName(for candidate: ImportCandidate, index: Int) -> String {
        if appliesFileNames {
            let labels = Array(timelineNames.prefix(Lanes.maxCount))
            if labels.indices.contains(index) { return labels[index] }
        }
        return lanes.label(index)
    }

    private func timelineIsAssigned(_ candidate: ImportCandidate) -> Bool {
        if appliesFileNames { return true }
        if showsTimelinePrompt { return choice != .single || !candidate.rawLane.isEmpty }
        return candidate.laneIndex != nil
    }

    private func mappingBinding(for name: String) -> Binding<Int> {
        let key = CategoryCatalog.normalize(name)
        return Binding(
            get: { mapping[key] ?? 0 },
            set: { mapping[key] = $0 }
        )
    }

    private func listed(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default:
            let head = names.dropLast().joined(separator: ", ")
            return "\(head), and \(names.last ?? "")"
        }
    }

    @ViewBuilder
    private func statusIcon(for candidate: ImportCandidate) -> some View {
        let (symbol, color): (String, Color) = switch candidate.status {
        case .ready: ("checkmark.circle.fill", .green)
        case .warning: ("exclamationmark.triangle.fill", .orange)
        case .error: ("xmark.octagon.fill", .red)
        }
        Image(systemName: symbol)
            .foregroundStyle(color)
            .help(candidate.issues.isEmpty ? "Ready to import" : candidate.issues.joined(separator: "\n"))
    }

    private func includeBinding(for id: Int) -> Binding<Bool> {
        Binding(
            get: { candidates.first { $0.id == id }?.include ?? false },
            set: { value in
                if let index = candidates.firstIndex(where: { $0.id == id }) {
                    candidates[index].include = value
                }
            })
    }
}

private struct SummaryPill: View {
    let count: Int
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        Label("\(count) \(label)", systemImage: symbol)
            .font(.system(size: 12, weight: .medium))
            .labelStyle(PillLabelStyle(color: color))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}

private struct PillLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.foregroundStyle(color)
            configuration.title.monospacedDigit()
        }
    }
}
