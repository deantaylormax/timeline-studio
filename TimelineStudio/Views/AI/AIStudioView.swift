import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PDFKit

/// One natural-language request. The timeline updates, then a link opens the event.
struct AIStudioView: View {
    @Environment(SubscriptionCenter.self) private var subscription
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var instructionFocused: Bool
    @Query(sort: \TimelineEvent.date) private var events: [TimelineEvent]
    @Query(sort: \TimelineDivider.date) private var dividers: [TimelineDivider]
    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]

    private var lanes = LaneSettings()

    @State private var tool: AITool = .edit
    @State private var instruction = ""
    @State private var focus = ""
    @State private var sourceName = ""
    @State private var sourceText = ""
    @State private var sourceTruncated = false
    @State private var pickingFile = false
    @State private var editingModel = false
    @State private var apiKeyDraft = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var proposal: AIProposal?
    @State private var findings: [AIFinding] = []
    @State private var narrative: AINarrative?
    @State private var appliedSummary = ""
    @State private var idleMessage = ""
    @State private var task: Task<Void, Never>?

    private var catalog: CategoryCatalog { CategoryCatalog(custom: customCategories) }

    private var lanePairs: [(index: Int, name: String)] {
        (0..<lanes.count).map { ($0, lanes.label($0)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    accessSection
                    if subscription.modelReady {
                        if tool == .edit {
                            requestTool
                        } else {
                            Button("Back to request") { tool = .edit }
                                .buttonStyle(.link)
                            toolBody
                        }
                    } else if subscription.usesOwnModel {
                        Text("Save a model name and an API key to try the tools.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    if let errorText {
                        Text(errorText)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 480, minHeight: tool == .edit ? 220 : 560)
        .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.pdf, .plainText, .text]) { result in
            loadFile(result)
        }
        .onAppear {
            editingModel = subscription.usesOwnModel && !subscription.modelReady
            instructionFocused = true
        }
        .onDisappear {
            if busy { task?.cancel() }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI")
                    .font(.title2.weight(.semibold))
                Text(subscription.usesOwnModel
                     ? "Type a change and press Return. A link opens the event so you can review and edit it."
                     : "\(subscription.tier.title) · \(subscription.tier.price). Requests go to the hosted model.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Extract from a Document…") { tool = .extract }
                Button("Review the Timeline") { tool = .review }
                Button("Write a Memo") { tool = .narrative }
            } label: {
                Text("More")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            if busy {
                ProgressView()
                    .controlSize(.small)
                Button("Cancel") { task?.cancel() }
            }
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }

    @ViewBuilder
    private var accessSection: some View {
        switch subscription.tier {
        case .free, .pro:
            modelSection
        case .privateAI:
            Text(subscription.modelReady
                 ? "Requests go to the hosted model in Google Cloud Assured Workloads."
                 : AIClientError.privateAIUnconfigured.localizedDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(modelSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(editingModel ? "Hide Model" : "Change Model") { editingModel.toggle() }
            }
            if editingModel {
                Picker("Provider", selection: Binding(
                    get: { subscription.provider },
                    set: { subscription.select($0) }
                )) {
                    ForEach(ModelProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                TextField("Model name", text: Bindable(subscription).modelName)
                    .textFieldStyle(.roundedBorder)
                if subscription.provider.baseURLIsEditable {
                    TextField("Model address", text: Bindable(subscription).baseURL)
                        .textFieldStyle(.roundedBorder)
                }
                SecureField(subscription.hasAPIKey ? "Replace saved API key" : "API key", text: $apiKeyDraft)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save Model") {
                        subscription.persistModelSettings()
                        subscription.saveAPIKey(apiKeyDraft)
                        apiKeyDraft = ""
                        if subscription.modelReady { editingModel = false }
                    }
                    if subscription.hasAPIKey {
                        Button("Remove Key") {
                            subscription.removeAPIKey()
                            apiKeyDraft = ""
                        }
                    }
                }
                Text("Your timeline is sent only to this provider.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var modelSummary: String {
        let name = subscription.modelName.trimmingCharacters(in: .whitespaces)
        let shown = name.isEmpty ? "No model name yet" : name
        let key = subscription.hasAPIKey ? "key saved" : (subscription.provider.requiresKey ? "key needed" : "no key")
        return "\(subscription.provider.title) · \(shown) · \(key)"
    }

    @ViewBuilder
    private var toolBody: some View {
        switch tool {
        case .edit:
            requestTool
        case .extract:
            extractTool
        case .review:
            reviewTool
        case .narrative:
            narrativeTool
        }
    }

    private var requestTool: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Add a text message that the offer was accepted", text: $instruction)
                .textFieldStyle(.roundedBorder)
                .focused($instructionFocused)
                .onSubmit(submitRequest)
                .disabled(busy)
            Text("The API key stays in the keychain on this Mac and is not part of the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if busy {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Working…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            if !idleMessage.isEmpty {
                Text(idleMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var extractTool: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AITool.extract.headline).font(.headline)
            Text("Reads the text in a PDF or text file, including page numbers. A scan with no text layer stays unread.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Button("Choose Document…") { pickingFile = true }
                if !sourceName.isEmpty {
                    Text(sourceTruncated ? "\(sourceName) · truncated" : sourceName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            TextField("Optional focus, such as medical visits", text: $focus)
                .textFieldStyle(.roundedBorder)
            runButton("Extract Events", disabled: sourceText.isEmpty) {
                await runExtract()
            }
            proposalView
        }
    }

    private var reviewTool: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AITool.review.headline).font(.headline)
            Text("Looks for statements that disagree, missing stretches of time, and sequences that cannot happen.")
                .font(.callout)
                .foregroundStyle(.secondary)
            runButton("Review Timeline", disabled: events.isEmpty) {
                await runReview()
            }
            if findings.isEmpty {
                if !appliedSummary.isEmpty, tool == .review {
                    Text(appliedSummary).font(.callout).foregroundStyle(.secondary)
                }
            } else {
                ForEach(findings) { finding in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(finding.title).font(.headline)
                        Text(finding.kind.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !finding.detail.isEmpty {
                            Text(finding.detail)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
                }
            }
        }
    }

    private var narrativeTool: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AITool.narrative.headline).font(.headline)
            Text("A memo you can copy. It cites events by date and title.")
                .font(.callout)
                .foregroundStyle(.secondary)
            runButton("Write Memo", disabled: events.isEmpty) {
                await runNarrative()
            }
            if let narrative {
                Text(narrative.title).font(.headline)
                Text(narrative.body)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("\(narrative.title)\n\n\(narrative.body)", forType: .string)
                }
            }
        }
    }

    @ViewBuilder
    private var proposalView: some View {
        if let proposal {
            if !proposal.summary.isEmpty {
                Text(proposal.summary)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if proposal.adds.isEmpty && proposal.changes.isEmpty {
                Text("Nothing to apply.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(proposal.adds) { proposed in
                labeledRow(
                    title: "Add · \(proposed.title)",
                    detail: "\(proposed.date.formatted(date: .abbreviated, time: proposed.isAllDay ? .omitted : .shortened)) · \(catalog.category(for: proposed.categoryID).name) · Timeline \(proposed.laneIndex + 1)")
            }
            ForEach(proposal.changes) { change in
                labeledRow(
                    title: change.delete ? "Delete · \(change.headline)" : "Update · \(change.headline)",
                    detail: change.detail)
            }
            ForEach(Array(proposal.skipped.enumerated()), id: \.offset) { _, note in
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            if !proposal.adds.isEmpty || !proposal.changes.isEmpty {
                Button("Apply") { apply(proposal) }
                    .keyboardShortcut(.defaultAction)
            }
        } else if !appliedSummary.isEmpty, tool == .edit || tool == .extract {
            Text(appliedSummary).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func labeledRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.callout.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func runButton(_ title: String, disabled: Bool, action: @escaping () async -> Void) -> some View {
        Button(title) {
            task = Task { await action() }
        }
        .disabled(busy || disabled || !subscription.modelReady)
    }

    private func submitRequest() {
        guard !busy else { return }
        guard !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        task = Task { await runRequest() }
    }

    private func runRequest() async {
        let request = AITimeline.editRequest(
            instruction: instruction,
            events: events,
            dividers: dividers,
            catalog: catalog,
            lanes: lanePairs)
        errorText = nil
        idleMessage = ""
        busy = true
        defer { busy = false }
        do {
            let text = try await AIClient.complete(system: request.system, user: request.user, connection: try subscription.connection())
            try Task.checkCancellation()
            let parsed = try AITimeline.parseEdits(text, events: events, catalog: catalog, laneCount: lanes.count)
            let notice = AITimeline.apply(parsed, context: modelContext, events: events, catalog: catalog)
            if notice.didChange {
                appState.aiNotice = notice
                dismiss()
            } else {
                idleMessage = notice.message
            }
        } catch is CancellationError {
            errorText = nil
        } catch let urlError as URLError where urlError.code == .cancelled {
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func runExtract() async {
        let request = AITimeline.extractRequest(
            documentName: sourceName,
            documentText: sourceText,
            focus: focus,
            catalog: catalog,
            lanes: lanePairs)
        await perform {
            let text = try await AIClient.complete(system: request.system, user: request.user, connection: try subscription.connection())
            proposal = try AITimeline.parseExtraction(text, catalog: catalog, laneCount: lanes.count)
            findings = []
            narrative = nil
            appliedSummary = ""
        }
    }

    private func runReview() async {
        let request = AITimeline.reviewRequest(events: events, dividers: dividers, catalog: catalog, lanes: lanePairs)
        await perform {
            let text = try await AIClient.complete(system: request.system, user: request.user, connection: try subscription.connection())
            findings = try AITimeline.parseFindings(text)
            proposal = nil
            narrative = nil
            appliedSummary = findings.isEmpty ? "No contradictions, gaps, or impossible sequences were reported." : ""
        }
    }

    private func runNarrative() async {
        let request = AITimeline.narrativeRequest(events: events, dividers: dividers, catalog: catalog, lanes: lanePairs)
        await perform {
            let text = try await AIClient.complete(system: request.system, user: request.user, connection: try subscription.connection())
            narrative = try AITimeline.parseNarrative(text)
            proposal = nil
            findings = []
            appliedSummary = ""
        }
    }

    private func perform(_ work: () async throws -> Void) async {
        errorText = nil
        idleMessage = ""
        busy = true
        defer { busy = false }
        do {
            try await work()
        } catch is CancellationError {
            errorText = nil
        } catch let urlError as URLError where urlError.code == .cancelled {
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func apply(_ proposal: AIProposal) {
        let notice = AITimeline.apply(proposal, context: modelContext, events: events, catalog: catalog)
        self.proposal = nil
        if notice.didChange {
            appState.aiNotice = notice
            dismiss()
        } else {
            appliedSummary = notice.message
        }
    }

    private func loadFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorText = error.localizedDescription
        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try Self.readDocument(url)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    sourceName = ""
                    sourceText = ""
                    errorText = "This file has no text layer to read. A scanned page needs OCR, which is not in this version."
                    return
                }
                sourceName = url.lastPathComponent
                sourceText = text
                sourceTruncated = text.count > AITimeline.documentLimit
                errorText = nil
                proposal = nil
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private static func readDocument(_ url: URL) throws -> String {
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return (0..<document.pageCount).compactMap { index in
                guard let page = document.page(at: index)?.string else { return nil }
                return "--- page \(index + 1) ---\n\(page)"
            }.joined(separator: "\n")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
