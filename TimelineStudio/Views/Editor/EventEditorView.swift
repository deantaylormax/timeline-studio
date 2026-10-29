import SwiftUI
import SwiftData

struct EventDraft {
    var date: Date
    var isAllDay: Bool
    var categoryID: String
    var title: String
    var notes: String
    var location: String
    var amountText: String
    var laneIndex: Int
    var attachmentBookmark: Data?
    var attachmentFileName: String
    var attachmentContentType: String
    var attachmentPage: Int?
    var attachmentStartText: String

    init(target: EditorTarget) {
        switch target {
        case .new(let date):
            self.date = date ?? Self.roundedNow()
            isAllDay = false
            categoryID = EventCategory.noteID
            title = ""
            notes = ""
            location = ""
            amountText = ""
            laneIndex = 0
            attachmentBookmark = nil
            attachmentFileName = ""
            attachmentContentType = ""
            attachmentPage = nil
            attachmentStartText = ""
        case .edit(let event):
            date = event.date
            isAllDay = event.isAllDay
            categoryID = event.categoryID
            title = event.title
            notes = event.notes
            location = event.location
            amountText = event.amount.map { String(format: "%.2f", $0) } ?? ""
            laneIndex = event.laneIndex
            attachmentBookmark = event.attachmentBookmark
            attachmentFileName = event.attachmentFileName
            attachmentContentType = event.attachmentContentType
            attachmentPage = event.attachmentPage
            attachmentStartText = event.attachmentStart.map(AttachmentTime.format) ?? ""
        }
    }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var amount: Double? {
        amountText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : CSVImporter.parseAmount(amountText)
    }

    private var normalizedDate: Date {
        isAllDay ? Calendar.current.startOfDay(for: date) : date
    }

    func apply(to event: TimelineEvent) {
        event.date = normalizedDate
        event.isAllDay = isAllDay
        event.categoryID = categoryID
        event.title = trimmedTitle
        event.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        event.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        event.amount = amount
        event.laneIndex = laneIndex
        event.attachmentBookmark = attachmentBookmark
        event.attachmentFileName = attachmentFileName
        event.attachmentContentType = attachmentContentType
        event.attachmentPage = attachmentPage
        event.attachmentStart = AttachmentTime.parse(attachmentStartText)
    }

    mutating func clearAttachment() {
        attachmentBookmark = nil
        attachmentFileName = ""
        attachmentContentType = ""
        attachmentPage = nil
        attachmentStartText = ""
    }

    var attachmentKind: AttachmentKind {
        AttachmentKind.detect(contentType: attachmentContentType, fileName: attachmentFileName)
    }

    func makeEvent() -> TimelineEvent {
        let event = TimelineEvent(date: normalizedDate, categoryID: categoryID, title: trimmedTitle)
        apply(to: event)
        return event
    }

    private static func roundedNow() -> Date {
        let calendar = Calendar.current
        let now = Date.now
        let minute = calendar.component(.minute, from: now)
        let rounded = calendar.date(byAdding: .minute, value: (5 - minute % 5) % 5, to: now) ?? now
        return calendar.date(bySetting: .second, value: 0, of: rounded) ?? rounded
    }
}

struct EventEditorView: View {
    let target: EditorTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.categoryCatalog) private var catalog
    @State private var draft: EventDraft
    @State private var linkError: String?
    @FocusState private var isTitleFocused: Bool
    private var lanes = LaneSettings()

    init(target: EditorTarget) {
        self.target = target
        _draft = State(initialValue: EventDraft(target: target))
    }

    private var editingEvent: TimelineEvent? {
        if case .edit(let event) = target { event } else { nil }
    }

    private var category: EventCategory { catalog.category(for: draft.categoryID) }

    private var showsAmount: Bool {
        draft.categoryID == EventCategory.purchaseID || !draft.amountText.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            form
            Divider()
            footer
        }
        .frame(width: 560, height: 780)
        .alert("Couldn’t Link File", isPresented: Binding(
            get: { linkError != nil }, set: { if !$0 { linkError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(linkError ?? "")
        }
        .onAppear {
            draft.laneIndex = min(max(draft.laneIndex, 0), lanes.count - 1)
            if editingEvent == nil { isTitleFocused = true }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            CategoryBadge(category: category, size: 44, rounded: true)
                .shadow(color: category.color.opacity(0.35), radius: 8, y: 3)
                .id(category.id)
                .transition(.scale(scale: 0.7).combined(with: .opacity))

            VStack(alignment: .leading, spacing: 2) {
                Text(editingEvent == nil ? "New Event" : "Edit Event")
                    .font(.system(size: 17, weight: .semibold))
                Text("\(category.name) · \(draft.date.formatted(date: .abbreviated, time: draft.isAllDay ? .omitted : .shortened))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var form: some View {
        Form {
            Section {
                TextField("Description", text: $draft.title, prompt: Text("What happened?"))
                    .labelsHidden()
                    .font(.system(size: 15, weight: .medium))
                    .focused($isTitleFocused)
            }

            Section("Type") {
                CategoryPickerGrid(selection: $draft.categoryID.animation(.spring(response: 0.35, dampingFraction: 0.8)))
            }

            if lanes.isMultiLane {
                Section("Timeline") {
                    Picker("Timeline", selection: $draft.laneIndex) {
                        ForEach(lanes.order, id: \.self) { lane in
                            Text(lanes.label(lane)).tag(lane)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            Section("When") {
                DatePicker("Date", selection: $draft.date,
                           displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])
                Toggle("All-day", isOn: $draft.isAllDay.animation(.snappy))
            }

            Section("Details") {
                TextField("Location", text: $draft.location, prompt: Text("Optional"))
                if showsAmount {
                    TextField("Amount", text: $draft.amountText,
                              prompt: Text(0.0.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))))
                        .transition(.opacity)
                }
            }

            Section("Notes") {
                TextField("Notes", text: $draft.notes, prompt: Text("Add details, quotes, or context…"), axis: .vertical)
                    .lineLimit(4...12)
                    .labelsHidden()
            }

            Section {
                if draft.attachmentFileName.isEmpty {
                    Button {
                        AttachmentPanels.chooseFile(linkFile)
                    } label: {
                        Label("Link a File…", systemImage: "paperclip")
                    }
                } else {
                    LabeledContent("File") {
                        HStack(spacing: 6) {
                            Image(systemName: draft.attachmentKind.symbol)
                                .foregroundStyle(category.color)
                            Text(draft.attachmentFileName)
                                .lineLimit(1)
                        }
                    }
                    if draft.attachmentKind == .pdf {
                        Stepper(value: Binding(
                            get: { draft.attachmentPage ?? 1 },
                            set: { draft.attachmentPage = $0 }
                        ), in: 1...999) {
                            Text("Open on page \(draft.attachmentPage ?? 1)")
                        }
                    }
                    if draft.attachmentKind == .video || draft.attachmentKind == .audio {
                        TextField("Start at", text: $draft.attachmentStartText, prompt: Text("0:00"))
                    }
                    HStack {
                        Button("Change…") { AttachmentPanels.chooseFile(linkFile) }
                        Button("Remove", role: .destructive) { draft.clearAttachment() }
                    }
                }
            } header: {
                Text("Linked File")
            } footer: {
                Text("The file stays where it is on this Mac. Export ▸ Timeline with Files copies every linked file into a portable timeline.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var footer: some View {
        HStack {
            if let event = editingEvent {
                Button("Delete", role: .destructive) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                        modelContext.delete(event)
                    }
                    dismiss()
                }
            }
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(editingEvent == nil ? "Add Event" : "Save") { save() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmedTitle.isEmpty)
        }
        .controlSize(.large)
        .padding(16)
    }

    private func save() {
        if let event = editingEvent {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                draft.apply(to: event)
            }
        } else {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                modelContext.insert(draft.makeEvent())
            }
        }
        try? modelContext.save()
        dismiss()
    }

    private func linkFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            linkError = error.localizedDescription
        case .success(let url):
            do {
                let linked = try AttachmentStore.bookmark(for: url)
                let previous = draft.attachmentKind
                draft.attachmentBookmark = linked.data
                draft.attachmentFileName = linked.fileName
                draft.attachmentContentType = linked.contentType
                let kind = draft.attachmentKind
                if kind != previous {
                    draft.attachmentPage = kind == .pdf ? 1 : nil
                    draft.attachmentStartText = ""
                }
            } catch {
                linkError = error.localizedDescription
            }
        }
    }
}

struct CategoryPickerGrid: View {
    @Binding var selection: String
    @Environment(\.categoryCatalog) private var catalog

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
            ForEach(catalog.all) { category in
                let isSelected = category.id == selection
                let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
                Button { selection = category.id } label: {
                    VStack(spacing: 6) {
                        CategoryBadge(category: category, size: 30, style: isSelected ? .solid : .soft, rounded: true)
                        Text(category.name)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .lineLimit(1)
                            .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(shape.fill(isSelected ? category.color.opacity(0.12) : Color.primary.opacity(0.035)))
                    .overlay(shape.strokeBorder(isSelected ? category.color.opacity(0.6) : .clear, lineWidth: 1.5))
                    .contentShape(shape)
                }
                .buttonStyle(.plain)
                .help(category.name)
                .accessibilityLabel(category.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
