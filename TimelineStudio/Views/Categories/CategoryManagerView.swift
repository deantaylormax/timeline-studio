import SwiftUI
import SwiftData

/// Built-in categories stay as they shipped. Anything else is created here:
/// a name, a tint, and an SF Symbol drawn in the same rounded tile.
struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]

    @State private var name = ""
    @State private var symbol = "star.fill"
    @State private var tint: CategoryTint = .pink
    @State private var symbolPinned = false
    @State private var editingID: String?
    @State private var iconSearch = ""
    @State private var page: Page = .icons

    private enum Page: String, CaseIterable, Identifiable {
        case icons, yours, builtIn
        var id: String { rawValue }
        var title: String {
            switch self {
            case .icons: "Icons"
            case .yours: "Yours"
            case .builtIn: "Built-in"
            }
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var suggestions: [CategorySymbol] {
        CategorySymbolLibrary.suggestions(matching: name)
    }

    private var visibleGroups: [CategorySymbolGroup] {
        CategorySymbolLibrary.groups(matching: iconSearch)
    }

    private var caption: String {
        if symbolPinned { return "Icon kept. Pick another to change it." }
        if trimmedName.isEmpty { return "Type a name. An icon is matched from it." }
        if suggestions.isEmpty { return "No close match. Pick an icon below." }
        return "Matched from the name. Click an icon to keep that one."
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            composer
            Divider()
            Picker("Show", selection: $page) {
                ForEach(Page.allCases) { page in
                    Text(page.title).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Group {
                switch page {
                case .icons: iconBrowser
                case .yours: customList
                case .builtIn: builtInList
                }
            }
            .frame(maxHeight: .infinity)

            Divider()
            footer
        }
        .frame(width: 520, height: 680)
    }

    private var header: some View {
        HStack(spacing: 14) {
            IconTile(symbol: "square.grid.2x2.fill", color: .accentColor, size: 44, rounded: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Categories").font(.system(size: 17, weight: .semibold))
                Text("Seven types ship with the app. Add your own, with an icon in the same style.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                IconTile(symbol: symbol, color: tint.color, size: 44, rounded: true)
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Name", text: $name, prompt: Text(editingID == nil ? "e.g. Hospital, Flight, Hearing" : "Category name"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(save)
                    Text(caption)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                VStack(spacing: 6) {
                    Button(editingID == nil ? "Add" : "Save", action: save)
                        .disabled(trimmedName.isEmpty)
                        .buttonStyle(.borderedProminent)
                    if editingID != nil {
                        Button("Cancel", action: resetForm)
                    }
                }
                .controlSize(.regular)
            }

            HStack(spacing: 8) {
                ForEach(CategoryTint.allCases) { candidate in
                    Button { tint = candidate } label: {
                        Circle()
                            .fill(candidate.color.gradient)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().strokeBorder(.white, lineWidth: candidate == tint ? 2 : 0))
                            .overlay(Circle().strokeBorder(candidate.color, lineWidth: candidate == tint ? 1 : 0).padding(-2))
                    }
                    .buttonStyle(.plain)
                    .help(candidate.rawValue.capitalized)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: name) { _, newValue in
            guard !symbolPinned else { return }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                symbol = "star.fill"
            } else if let match = CategorySymbolLibrary.suggestions(matching: newValue, limit: 1).first {
                symbol = match.name
            }
        }
    }

    private var iconBrowser: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search icons", text: $iconSearch)
                    .textFieldStyle(.plain)
                if !iconSearch.isEmpty {
                    Button { iconSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if iconSearch.isEmpty, !suggestions.isEmpty {
                        symbolSection("Suggested", symbols: suggestions)
                    }
                    if visibleGroups.isEmpty {
                        Text("No icons match that search.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(visibleGroups) { group in
                            symbolSection(group.title, symbols: group.symbols)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func symbolSection(_ title: String, symbols: [CategorySymbol]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                ForEach(symbols) { candidate in
                    symbolButton(candidate)
                }
            }
        }
    }

    private func symbolButton(_ candidate: CategorySymbol) -> some View {
        let isSelected = candidate.name == symbol
        let label = candidate.keywords.first?.capitalized ?? candidate.name
        return Button {
            symbol = candidate.name
            symbolPinned = true
        } label: {
            IconTile(symbol: candidate.name, color: tint.color, size: 32, rounded: true)
                .padding(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isSelected ? Color.primary.opacity(0.85) : Color.clear, lineWidth: 1.5)
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var customList: some View {
        Group {
            if customCategories.isEmpty {
                VStack(spacing: 6) {
                    Text("No categories of your own yet.")
                        .font(.system(size: 13, weight: .medium))
                    Text("Name one above. The icon follows the name, and you can pick a different symbol.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(customCategories) { custom in
                            HStack(spacing: 10) {
                                row(custom.category)
                                Button { beginEdit(custom) } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .help("Edit \(custom.name)")
                                Button(role: .destructive) {
                                    if editingID == custom.id { resetForm() }
                                    withAnimation { modelContext.delete(custom) }
                                    try? modelContext.save()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Delete \(custom.name). Its events become Notes.")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(editingID == custom.id ? Color.accentColor.opacity(0.08) : Color.clear)
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    private var builtInList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("These seven stay available on every timeline.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                ForEach(EventCategory.builtIns) { category in
                    row(category)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                    Divider().padding(.leading, 16)
                }
            }
            .padding(.top, 4)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
        .padding(16)
    }

    private func row(_ category: EventCategory) -> some View {
        HStack(spacing: 10) {
            CategoryBadge(category: category, size: 24, rounded: true)
            Text(category.name)
                .lineLimit(1)
            Spacer(minLength: 4)
        }
    }

    private func beginEdit(_ custom: CustomCategory) {
        editingID = custom.id
        name = custom.name
        symbol = custom.symbol
        tint = custom.tint
        symbolPinned = true
        page = .icons
    }

    private func resetForm() {
        name = ""
        symbol = "star.fill"
        symbolPinned = false
        editingID = nil
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        if let editingID, let existing = customCategories.first(where: { $0.id == editingID }) {
            existing.name = trimmedName
            existing.symbol = symbol
            existing.tintRaw = tint.rawValue
        } else {
            modelContext.insert(CustomCategory(name: trimmedName, symbol: symbol, tint: tint))
        }
        try? modelContext.save()
        resetForm()
    }
}
