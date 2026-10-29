import SwiftUI
import SwiftData

enum DividerTarget: Identifiable {
    case new(Date)
    case edit(TimelineDivider)

    var id: String {
        switch self {
        case .new: "new-divider"
        case .edit(let divider): divider.id.uuidString
        }
    }
}

/// Creates or edits a chapter divider: its label and the moment it marks.
struct DividerEditorView: View {
    let target: DividerTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title: String
    @State private var date: Date
    @FocusState private var isTitleFocused: Bool

    init(target: DividerTarget) {
        self.target = target
        switch target {
        case .new(let date):
            _title = State(initialValue: "")
            _date = State(initialValue: date)
        case .edit(let divider):
            _title = State(initialValue: divider.title)
            _date = State(initialValue: divider.date)
        }
    }

    private var editing: TimelineDivider? {
        if case .edit(let divider) = target { divider } else { nil }
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                IconTile(symbol: "bookmark.fill", color: .accentColor, size: 44, rounded: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(editing == nil ? "New Divider" : "Edit Divider")
                        .font(.system(size: 17, weight: .semibold))
                    Text("A labelled chapter line across your timeline.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            Divider()

            Form {
                Section {
                    TextField("Label", text: $title, prompt: Text("e.g. Person arrives"))
                        .labelsHidden()
                        .font(.system(size: 15, weight: .medium))
                        .focused($isTitleFocused)
                }
                Section {
                    DatePicker("Placed at", selection: $date, displayedComponents: [.date, .hourAndMinute])
                } footer: {
                    Text("A divider sits just before any event at the same moment, and in presentations it gets its own step.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if let divider = editing {
                    Button("Delete", role: .destructive) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { modelContext.delete(divider) }
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(editing == nil ? "Add Divider" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedTitle.isEmpty)
            }
            .controlSize(.large)
            .padding(16)
        }
        .frame(width: 460, height: 380)
        .onAppear { isTitleFocused = true }
    }

    private func save() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            if let divider = editing {
                divider.title = trimmedTitle
                divider.date = date
            } else {
                modelContext.insert(TimelineDivider(date: date, title: trimmedTitle))
            }
        }
        try? modelContext.save()
        dismiss()
    }
}
