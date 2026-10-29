import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum ExportFormat {
    case pdf, png

    var contentType: UTType { self == .pdf ? .pdf : .png }
    var fileExtension: String { self == .pdf ? "pdf" : "png" }
}

enum ExportError: LocalizedError {
    case renderFailed

    var errorDescription: String? { "The timeline couldn’t be rendered." }
}

@MainActor
enum TimelineExporter {
    static func export<Content: View>(_ view: Content, format: ExportFormat, suggestedName: String) {
        let appearance = NSApp.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let content = view.environment(\.colorScheme, isDark ? .dark : .light)

        let panel = NSSavePanel()
        panel.title = "Export Timeline"
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true
        let safeName = suggestedName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        panel.nameFieldStringValue = "\(safeName).\(format.fileExtension)"

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try write(content, format: format, to: url, appearance: appearance)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                NSAlert(error: error).runModal()
            }
        }

        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    static func write<Content: View>(_ content: Content, format: ExportFormat, to url: URL, appearance: NSAppearance) throws {
        var failure: Error?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            switch format {
            case .png:
                guard let image = renderer.cgImage else {
                    failure = ExportError.renderFailed
                    return
                }
                let rep = NSBitmapImageRep(cgImage: image)
                rep.size = NSSize(width: CGFloat(image.width) / 2, height: CGFloat(image.height) / 2)
                guard let data = rep.representation(using: .png, properties: [:]) else {
                    failure = ExportError.renderFailed
                    return
                }
                do { try data.write(to: url, options: .atomic) } catch { failure = error }
            case .pdf:
                renderer.render { size, draw in
                    var box = CGRect(origin: .zero, size: size)
                    guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
                        failure = ExportError.renderFailed
                        return
                    }
                    context.beginPDFPage(nil)
                    draw(context)
                    context.endPDFPage()
                    context.closePDF()
                }
            }
        }
        if let failure { throw failure }
    }
}
