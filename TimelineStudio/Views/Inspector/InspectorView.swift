import SwiftUI

struct InspectorView: View {
    let onManageCategories: () -> Void
    let onExport: (ExportFormat) -> Void
    let onExportPackage: () -> Void
    let onPresent: () -> Void

    @AppStorage(PrefKey.title) private var title = TimelineDefaults.title
    @AppStorage(PrefKey.subtitle) private var subtitle = ""
    @AppStorage(PrefKey.yAxisLabel) private var yAxisLabel = ""
    @AppStorage(PrefKey.showYAxis) private var showYAxis = false
    @AppStorage(PrefKey.background) private var background: CanvasBackground = .paper
    @AppStorage(PrefKey.layout) private var layout: TimelineLayout = .vertical
    @AppStorage(PrefKey.newestFirst) private var newestFirst = false
    @AppStorage(PrefKey.showTimes) private var showTimes = true
    @AppStorage(PrefKey.presentationEntrance) private var entrance: PresentationEntrance = .appear
    @AppStorage(PrefKey.presentationExit) private var exitStyle: PresentationExit = .shrinkAndDim

    private var lanes = LaneSettings()

    private let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)

    var body: some View {
        Form {
            Section("Titles") {
                TextField("Title", text: $title, prompt: Text("Untitled Timeline"))
                TextField("Subtitle", text: $subtitle, prompt: Text("e.g. Personal Events 2024–2025"))
                Toggle("Y-Axis Label", isOn: $showYAxis.animation(spring))
                if showYAxis {
                    TextField("Label", text: $yAxisLabel.animation(spring), prompt: Text("e.g. Intensity"))
                }
            }

            Section("Layout") {
                Picker("Style", selection: $layout.animation(spring)) {
                    ForEach(TimelineLayout.allCases) { layout in
                        Text(layout.title).tag(layout)
                    }
                }
                Toggle("Newest First", isOn: $newestFirst.animation(spring))
                Toggle("Show Times", isOn: $showTimes.animation(spring))
            }

            Section("Background") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                    ForEach(CanvasBackground.allCases) { option in
                        BackgroundSwatch(option: option, isSelected: option == background) {
                            withAnimation(.easeInOut(duration: 0.3)) { background = option }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Picker("Timelines", selection: lanes.$storedCount.animation(spring)) {
                    ForEach(1...Lanes.maxCount, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                if lanes.isMultiLane {
                    ForEach(Array(lanes.order.enumerated()), id: \.element) { position, lane in
                        HStack(spacing: 8) {
                            Circle().fill(Lanes.tints[lane].gradient).frame(width: 10, height: 10)
                            TextField("Label", text: lanes.labelBinding(lane), prompt: Text(Lanes.defaultLabel(lane)))
                                .labelsHidden()
                            Button {
                                withAnimation(spring) { lanes.move(from: position, by: -1) }
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(position == 0)
                            .help("Move earlier")
                            .accessibilityLabel("Move \(lanes.label(lane)) earlier")
                            Button {
                                withAnimation(spring) { lanes.move(from: position, by: 1) }
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(position == lanes.order.count - 1)
                            .help("Move later")
                            .accessibilityLabel("Move \(lanes.label(lane)) later")
                        }
                    }
                    Picker("Labels", selection: lanes.$side.animation(spring)) {
                        ForEach(LaneLabelSide.allCases) { side in
                            Text(side.title).tag(side)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Timelines")
            } footer: {
                Text("Compare up to three sequences. The arrows set their order: first is on the left, or on top in the horizontal layout. You can also right-click a timeline’s name.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Entrance", selection: $entrance) {
                    ForEach(PresentationEntrance.allCases) { effect in
                        Text(effect.title).tag(effect)
                    }
                }
                Picker("Previous Events", selection: $exitStyle) {
                    ForEach(PresentationExit.allCases) { effect in
                        Text(effect.title).tag(effect)
                    }
                }
                Button(action: onPresent) {
                    Label("Start Presentation", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
            } header: {
                Text("Presentation")
            } footer: {
                Text("How each event enters the center, and how it looks once the next one takes its place.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Manage Categories…", action: onManageCategories)
            } header: {
                Text("Categories")
            } footer: {
                Text("Text Message, Phone Call, Email, Meeting, Outing, Purchase, and Note stay built in. Add your own and choose an icon.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button { onExport(.pdf) } label: {
                        Label("PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity)
                    }
                    Button { onExport(.png) } label: {
                        Label("Image", systemImage: "photo").frame(maxWidth: .infinity)
                    }
                }
                Button(action: onExportPackage) {
                    Label("Timeline with Files", systemImage: "doc.badge.plus").frame(maxWidth: .infinity)
                }
            } header: {
                Text("Export")
            } footer: {
                Text("Timeline with Files copies each linked file into a portable timeline. PDF and image export leave the files where they are.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct BackgroundSwatch: View {
    let option: CanvasBackground
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Button(action: action) {
            VStack(spacing: 6) {
                shape
                    .fill(option.fill)
                    .frame(height: 46)
                    .overlay(alignment: .bottomLeading) {
                        // A miniature card so the contrast against the background is visible.
                        HStack(spacing: 4) {
                            Circle().fill(Color.accentColor).frame(width: 7, height: 7)
                            Capsule().fill(.primary.opacity(0.15)).frame(width: 22, height: 4)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Palette.cardFill))
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        .padding(7)
                    }
                    .overlay(shape.strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                                                lineWidth: isSelected ? 2 : 0.5))
                Text(option.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.title) background")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
