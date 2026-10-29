import Foundation
import AppKit
import UniformTypeIdentifiers

/// What a linked file is, which decides the viewer and the icon on the card.
enum AttachmentKind: String {
    case pdf, image, video, audio, other

    var symbol: String {
        switch self {
        case .pdf: "doc.richtext"
        case .image: "photo"
        case .video: "film"
        case .audio: "waveform"
        case .other: "doc"
        }
    }

    var title: String {
        switch self {
        case .pdf: "PDF"
        case .image: "Image"
        case .video: "Video"
        case .audio: "Audio"
        case .other: "File"
        }
    }

    static func detect(contentType: String, fileName: String) -> AttachmentKind {
        if let type = UTType(contentType) ?? UTType(filenameExtension: (fileName as NSString).pathExtension) {
            if type.conforms(to: .pdf) { return .pdf }
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
            if type.conforms(to: .audio) { return .audio }
        }
        return .other
    }
}

enum AttachmentTime {
    static func format(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Accepts "90", "1:30", or "1:02:03".
    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":")
        guard parts.count <= 3 else { return nil }
        var values: [Double] = []
        for part in parts {
            guard let value = Double(part), value >= 0 else { return nil }
            values.append(value)
        }
        switch values.count {
        case 1: return values[0]
        case 2: return values[0] * 60 + values[1]
        case 3: return values[0] * 3600 + values[1] * 60 + values[2]
        default: return nil
        }
    }
}

enum AttachmentError: LocalizedError {
    case unreadable
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            "The file couldn’t be read."
        case .unavailable(let name):
            "“\(name)” isn’t available. It may have been moved or renamed. Relink it to open the file in its new location."
        }
    }
}

/// Resolves the bookmark stored on an event and holds the sandbox access open.
final class ScopedFile {
    let url: URL
    let isStale: Bool
    private let accessing: Bool
    private var didStop = false

    init(bookmark: Data) throws {
        var stale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        self.url = url
        self.isStale = stale
        accessing = url.startAccessingSecurityScopedResource()
    }

    func stop() {
        guard accessing, !didStop else { return }
        didStop = true
        url.stopAccessingSecurityScopedResource()
    }

    deinit { stop() }
}

@MainActor
enum AttachmentPanels {
    /// An open panel that works while the event editor sheet is up.
    static func chooseFile(_ perform: @escaping (Result<URL, Error>) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Link a File"
        panel.message = "The timeline keeps a link to this file on your Mac. It is not copied."
        panel.prompt = "Link"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = AttachmentStore.readableTypes
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            perform(.success(url))
        }
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }
}

enum AttachmentStore {
    static let readableTypes: [UTType] = [.pdf, .image, .movie, .video, .audio, .data]

    static func bookmark(for url: URL) throws -> (data: Data, fileName: String, contentType: String) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.identifier ?? "public.data"
        return (data, url.lastPathComponent, type)
    }

    /// A fresh bookmark for the same file, written back when the stored one has gone stale.
    static func refreshedBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}
