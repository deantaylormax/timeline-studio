import SwiftUI
import AppKit
import PDFKit
import AVKit
import Quartz

/// The control on a timeline card. Shown only when a file is linked.
struct AttachmentChip: View {
    let event: TimelineEvent
    let tint: Color
    let action: () -> Void

    private var kind: AttachmentKind {
        AttachmentKind.detect(contentType: event.attachmentContentType, fileName: event.attachmentFileName)
    }

    private var label: String {
        if let place = event.attachmentPlace {
            return "\(event.attachmentFileName) · \(place)"
        }
        return event.attachmentFileName
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .lineLimit(1)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help("Open \(event.attachmentFileName)")
        .accessibilityLabel("Open \(event.attachmentFileName)")
    }
}

/// A corner control for the focused card in a presentation, where the card itself ignores clicks.
struct AttachmentIconButton: View {
    let event: TimelineEvent
    let tint: Color
    let action: () -> Void

    private var kind: AttachmentKind {
        AttachmentKind.detect(contentType: event.attachmentContentType, fileName: event.attachmentFileName)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: kind.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.thinMaterial))
                .overlay(Circle().strokeBorder(tint.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Open \(event.attachmentFileName)")
        .accessibilityLabel("Open \(event.attachmentFileName)")
    }
}

/// Opens the file linked to an event so a presenter can show it and point at a spot.
struct AttachmentViewer: View {
    let event: TimelineEvent
    var onClose: () -> Void

    @State private var file: ScopedFile?
    @State private var failure: String?
    @State private var isPointing = false
    @State private var point: CGPoint?

    private var kind: AttachmentKind {
        AttachmentKind.detect(contentType: event.attachmentContentType, fileName: event.attachmentFileName)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ZStack {
                viewer
                PointerLayer(isPointing: isPointing, point: $point)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.04))
        }
        .frame(minWidth: 840, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: resolve)
        .onDisappear { file?.stop() }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.accentColor.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.attachmentFileName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    isPointing.toggle()
                    if !isPointing { point = nil }
                }
            } label: {
                Label(isPointing ? "Pointing" : "Point", systemImage: "scope")
            }
            .buttonStyle(.bordered)
            .tint(isPointing ? Color.accentColor : nil)
            .disabled(file == nil)
            .help(isPointing ? "Click the file to drop a marker. Click Point again to clear it." : "Drop a marker on the file")

            Button("Close", action: onClose)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var subtitle: String {
        var parts = [event.title.isEmpty ? "Linked file" : event.title, kind.title]
        if let place = event.attachmentPlace { parts.append(place) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var viewer: some View {
        if let failure {
            ContentUnavailableView {
                Label("File Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(failure)
            } actions: {
                Button("Relink…") { AttachmentPanels.chooseFile(relink) }
            }
        } else if let url = file?.url {
            fileView(url)
        } else {
            ProgressView("Opening \(event.attachmentFileName)")
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private func fileView(_ url: URL) -> some View {
        switch kind {
        case .pdf:
            PDFFileView(url: url, page: event.attachmentPage)
        case .image:
            ImageFileView(url: url)
        case .video:
            MediaFileView(url: url, start: event.attachmentStart, showsVideo: true)
        case .audio:
            VStack(spacing: 20) {
                Image(systemName: "waveform")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(event.attachmentFileName)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                MediaFileView(url: url, start: event.attachmentStart, showsVideo: false)
                    .frame(height: 72)
                    .frame(maxWidth: 640)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .other:
            QuickLookFileView(url: url)
        }
    }

    private func resolve() {
        guard let bookmark = event.attachmentBookmark else {
            failure = AttachmentError.unavailable(event.attachmentFileName).localizedDescription
            return
        }
        do {
            let scoped = try ScopedFile(bookmark: bookmark)
            if scoped.isStale, let refreshed = try? AttachmentStore.refreshedBookmark(for: scoped.url) {
                event.attachmentBookmark = refreshed
            }
            guard FileManager.default.isReadableFile(atPath: scoped.url.path) else {
                scoped.stop()
                failure = AttachmentError.unavailable(event.attachmentFileName).localizedDescription
                return
            }
            file = scoped
        } catch {
            failure = AttachmentError.unavailable(event.attachmentFileName).localizedDescription
        }
    }

    private func relink(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            failure = error.localizedDescription
        case .success(let url):
            do {
                let linked = try AttachmentStore.bookmark(for: url)
                event.attachmentBookmark = linked.data
                event.attachmentFileName = linked.fileName
                event.attachmentContentType = linked.contentType
                failure = nil
                file?.stop()
                file = nil
                point = nil
                resolve()
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

/// A temporary ring the presenter drops on the open file. It is not saved into the file.
private struct PointerLayer: View {
    let isPointing: Bool
    @Binding var point: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onEnded { value in
                            guard isPointing, geometry.frame(in: .local).contains(value.location) else { return }
                            point = value.location
                        }
                )
                .overlay {
                    if let point {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 2)
                                .background(Circle().fill(Color.accentColor.opacity(0.85)))
                                .frame(width: 18, height: 18)
                            Circle()
                                .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 2)
                                .frame(width: 44, height: 44)
                        }
                        .position(point)
                        .allowsHitTesting(false)
                    }
                }
                .allowsHitTesting(isPointing)
        }
    }
}

private struct PDFFileView: NSViewRepresentable {
    let url: URL
    let page: Int?

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.document = PDFDocument(url: url)
        if let page, let pdfPage = view.document?.page(at: max(page - 1, 0)) {
            DispatchQueue.main.async { view.go(to: pdfPage) }
        }
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {}
}

private struct ImageFileView: View {
    let url: URL

    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(24)
        } else {
            ContentUnavailableView("Couldn’t Display Image", systemImage: "photo",
                                   description: Text(url.lastPathComponent))
        }
    }
}

private struct MediaFileView: NSViewRepresentable {
    let url: URL
    let start: Double?
    let showsVideo: Bool

    func makeNSView(context: Context) -> AVPlayerView {
        let player = AVPlayer(url: url)
        if let start, start > 0.5 {
            player.seek(to: CMTime(seconds: start, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.showsFullScreenToggleButton = showsVideo
        if !showsVideo {
            view.videoGravity = .resizeAspect
        }
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}

private struct QuickLookFileView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSView {
        guard let view = QLPreviewView(frame: .zero, style: .normal) else { return NSView() }
        view.autostarts = true
        view.previewItem = url as QLPreviewItem
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? QLPreviewView else { return }
        if view.previewItem?.previewItemURL != url {
            view.previewItem = url as QLPreviewItem
        }
    }
}
