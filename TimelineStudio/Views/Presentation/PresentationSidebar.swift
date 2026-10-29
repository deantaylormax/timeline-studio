import SwiftUI

/// Bookmarks and category filters for a presentation. Dividers jump the shared clock.
/// Hiding a category only affects this presentation.
struct PresentationSidebar: View {
    struct CategoryRow: Identifiable {
        let category: EventCategory
        let count: Int
        let isShown: Bool
        var id: String { category.id }
    }

    let dividers: [TimelineDivider]
    let activeDividerID: UUID?
    let categories: [CategoryRow]
    let onSelect: (TimelineDivider) -> Void
    let onToggle: (String) -> Void
    let onCollapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dividerSection
                    categorySection
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.035))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Palette.cardStroke).frame(width: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Navigation")
                .font(.system(size: 13, weight: .semibold))
            Spacer(minLength: 0)
            Button(action: onCollapse) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Hide navigation")
            .accessibilityLabel("Hide navigation")
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var dividerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Dividers")
            if dividers.isEmpty {
                Text("No dividers yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            } else {
                ForEach(dividers, id: \.id) { divider in
                    let isActive = divider.id == activeDividerID
                    Button { onSelect(divider) } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                                .frame(width: 14, height: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(divider.displayTitle)
                                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(divider.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isActive ? Color.accentColor.opacity(0.14) : Color.clear)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go to \(divider.displayTitle)")
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                }
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Categories")
            if categories.isEmpty {
                Text("No events yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            } else {
                ForEach(categories) { row in
                    Button { onToggle(row.category.id) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: row.isShown ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(row.isShown ? row.category.color : Color.secondary)
                            Image(systemName: row.category.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(row.category.color)
                                .frame(width: 16)
                            Text(row.category.name)
                                .font(.system(size: 13, weight: row.isShown ? .medium : .regular))
                                .foregroundStyle(row.isShown ? Color.primary : Color.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(row.count)")
                                .font(.system(size: 11, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(row.category.name), \(row.isShown ? "shown" : "hidden")")
                    .accessibilityAddTraits(row.isShown ? .isSelected : [])
                }
            }
            Text("Hidden categories stay out of this presentation only.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.top, 6)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
    }
}
