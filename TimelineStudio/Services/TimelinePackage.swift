import Foundation
import AppKit

/// A portable timeline: `manifest.json` plus a copy of every linked file.
/// Events on this Mac keep their bookmarks to the original files. Opening the package
/// builds a timeline whose links point at the copies inside the package.
struct TimelinePackage: Codable, Sendable {
    static let manifestName = "manifest.json"
    static let version = 1

    var version: Int = TimelinePackage.version
    var title: String
    var subtitle: String
    var yAxisLabel: String
    var showYAxis: Bool
    var background: String
    var layout: String
    var newestFirst: Bool
    var showTimes: Bool
    var laneCount: Int
    var laneLabelSide: String
    var laneLabels: [String]
    /// Visual order of lane indexes. Missing in packages written before reordering existed.
    var laneOrder: [Int] = [0, 1, 2]
    var categories: [PackageCategory]
    var events: [PackageEvent]
    var dividers: [PackageDivider]
}

struct PackageCategory: Codable, Sendable {
    var id: String
    var name: String
    var symbol: String
    var tint: String
}

struct PackageEvent: Codable, Sendable {
    var id: UUID
    var date: Date
    var isAllDay: Bool
    var categoryID: String
    var title: String
    var notes: String
    var location: String
    var amount: Double?
    var laneIndex: Int
    var attachment: PackageAttachment?
}

struct PackageAttachment: Codable, Sendable {
    var fileName: String
    var contentType: String
    /// Path inside the package, relative to the package root.
    var relativePath: String
    var page: Int?
    var startSeconds: Double?
}

struct PackageDivider: Codable, Sendable {
    var id: UUID
    var date: Date
    var title: String
}

struct PackageFile: Sendable {
    var eventTitle: String
    var fileName: String
    var bookmark: Data
    var relativePath: String
}

struct PackageFailure: Identifiable, Sendable {
    var id: String { "\(eventTitle)-\(fileName)" }
    var eventTitle: String
    var fileName: String
    var reason: String
}

/// One event ready to insert, with a bookmark aimed at the copy inside the package.
struct ImportedPackageEvent {
    var event: PackageEvent
    var bookmark: Data?
}

struct ImportedTimelinePackage {
    var package: TimelinePackage
    var events: [ImportedPackageEvent]
    var missingFiles: [String]
}

enum TimelinePackageError: LocalizedError {
    case unreadable
    case notATimeline

    var errorDescription: String? {
        switch self {
        case .unreadable: "The timeline couldn’t be read."
        case .notATimeline: "That folder doesn’t contain a Timeline Studio package."
        }
    }
}

enum TimelinePackageIO {
    static func packed(_ event: TimelineEvent) -> (record: PackageEvent, file: PackageFile?) {
        var attachment: PackageAttachment?
        var file: PackageFile?
        if event.hasAttachment, let bookmark = event.attachmentBookmark {
            let relative = "Files/\(event.id.uuidString)/\(sanitized(event.attachmentFileName))"
            attachment = PackageAttachment(
                fileName: event.attachmentFileName,
                contentType: event.attachmentContentType,
                relativePath: relative,
                page: event.attachmentPage,
                startSeconds: event.attachmentStart
            )
            file = PackageFile(eventTitle: event.title, fileName: event.attachmentFileName,
                               bookmark: bookmark, relativePath: relative)
        }
        let record = PackageEvent(
            id: event.id, date: event.date, isAllDay: event.isAllDay, categoryID: event.categoryID,
            title: event.title, notes: event.notes, location: event.location, amount: event.amount,
            laneIndex: event.laneIndex, attachment: attachment
        )
        return (record, file)
    }

    static func makeEvent(_ imported: ImportedPackageEvent) -> TimelineEvent {
        let source = imported.event
        let event = TimelineEvent(
            date: source.date, isAllDay: source.isAllDay, categoryID: source.categoryID,
            title: source.title, notes: source.notes, location: source.location,
            amount: source.amount, laneIndex: source.laneIndex
        )
        if let attachment = source.attachment {
            event.attachmentBookmark = imported.bookmark
            event.attachmentFileName = attachment.fileName
            event.attachmentContentType = attachment.contentType
            event.attachmentPage = attachment.page
            event.attachmentStart = attachment.startSeconds
        }
        return event
    }

    /// Copies linked files into `directory` and writes the manifest. Returns files that could not be copied.
    static func write(_ package: TimelinePackage, files: [PackageFile], to directory: URL) throws -> [PackageFailure] {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? (directory as NSURL).setResourceValue(true, forKey: .isPackageKey)

        var failures: [PackageFailure] = []
        var written = package
        var kept: [PackageEvent] = []
        for event in package.events {
            var event = event
            if let attachment = event.attachment,
               let file = files.first(where: { $0.relativePath == attachment.relativePath }) {
                let destination = directory.appendingPathComponent(attachment.relativePath)
                do {
                    try copyBookmark(file.bookmark, to: destination)
                } catch {
                    failures.append(PackageFailure(eventTitle: file.eventTitle, fileName: file.fileName,
                                                   reason: error.localizedDescription))
                    event.attachment = nil
                }
            }
            kept.append(event)
        }
        written.events = kept

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(written)
        try data.write(to: directory.appendingPathComponent(TimelinePackage.manifestName), options: .atomic)
        return failures
    }

    /// Reads a package while `root` is still inside an open-panel security scope.
    static func read(at root: URL) throws -> ImportedTimelinePackage {
        let accessing = root.startAccessingSecurityScopedResource()
        defer { if accessing { root.stopAccessingSecurityScopedResource() } }

        let manifest = root.appendingPathComponent(TimelinePackage.manifestName)
        guard FileManager.default.fileExists(atPath: manifest.path) else { throw TimelinePackageError.notATimeline }
        let data = try Data(contentsOf: manifest)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let package: TimelinePackage
        do {
            package = try decoder.decode(TimelinePackage.self, from: Self.withLaneOrder(data))
        } catch {
            throw TimelinePackageError.unreadable
        }

        var imported: [ImportedPackageEvent] = []
        var missing: [String] = []
        for event in package.events {
            var bookmark: Data?
            if let attachment = event.attachment {
                let fileURL = root.appendingPathComponent(attachment.relativePath)
                if FileManager.default.fileExists(atPath: fileURL.path),
                   let data = try? fileURL.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                   ) {
                    bookmark = data
                } else {
                    missing.append(attachment.fileName)
                }
            }
            imported.append(ImportedPackageEvent(event: event, bookmark: bookmark))
        }
        return ImportedTimelinePackage(package: package, events: imported, missingFiles: missing)
    }

    private static func copyBookmark(_ bookmark: Data, to destination: URL) throws {
        let scoped = try ScopedFile(bookmark: bookmark)
        defer { scoped.stop() }
        guard FileManager.default.isReadableFile(atPath: scoped.url.path) else { throw AttachmentError.unreadable }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: scoped.url, to: destination)
    }

    /// Older packages have no `laneOrder`. Fill it in so decoding keeps a single shape.
    static func withLaneOrder(_ data: Data) -> Data {
        guard var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return data }
        if root["laneOrder"] == nil { root["laneOrder"] = [0, 1, 2] }
        return (try? JSONSerialization.data(withJSONObject: root)) ?? data
    }

    static func summary(copied: Int, failures: [PackageFailure]) -> String {
        let copiedText = copied == 1 ? "1 linked file was copied into the timeline." : "\(copied) linked files were copied into the timeline."
        guard !failures.isEmpty else {
            return copied == 0
                ? "The timeline was saved. None of the events have a linked file yet."
                : "\(copiedText) The events on this Mac still open the original files."
        }
        let names = failures.map(\.fileName).joined(separator: ", ")
        return "\(copiedText) These files could not be copied: \(names)."
    }

    static func sanitized(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "File" : cleaned
    }
}

@MainActor
enum TimelinePackagePanels {
    static func save(suggestedName: String, perform: @escaping (URL) -> Void) {
        let panel = NSSavePanel()
        panel.title = "Export Timeline with Files"
        panel.message = "Copies every linked file into this timeline. Events on this Mac keep pointing at the original files."
        panel.prompt = "Export"
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(TimelinePackageIO.sanitized(suggestedName)).timeline"
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            perform(url)
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    static func open(perform: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Open Timeline with Files"
        panel.message = "Choose a timeline exported with its linked files."
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            perform(url)
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }
}
