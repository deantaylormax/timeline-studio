import SwiftUI

struct TimelineCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Event…") { appState.perform(.newEvent) }
                .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(after: .newItem) {
            Divider()
            Button("Import CSV…") { appState.perform(.importCSV) }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            Menu("Export") {
                Button("PDF…") { appState.perform(.exportPDF) }
                    .keyboardShortcut("e", modifiers: .command)
                Button("PNG Image…") { appState.perform(.exportImage) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Divider()
                Button("Timeline with Files…") { appState.perform(.exportPackage) }
                    .keyboardShortcut("e", modifiers: [.command, .option])
            }
            Button("Open Timeline with Files…") { appState.perform(.openPackage) }
                .keyboardShortcut("o", modifiers: [.command, .option])
        }

        CommandMenu("Timeline") {
            Button("Add Divider…") { appState.perform(.newDivider) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("Start Presentation") { appState.perform(.startPresentation) }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(appState.isPresenting)
            Divider()
            ForEach(Array(TimelineLayout.allCases.enumerated()), id: \.element) { index, layout in
                Button(layout.title) {
                    UserDefaults.standard.set(layout.rawValue, forKey: PrefKey.layout)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
            Divider()
            Button("Expand All Notes") { appState.perform(.expandAllNotes) }
                .keyboardShortcut("]", modifiers: [.command, .option])
            Button("Collapse All Notes") { appState.perform(.collapseAllNotes) }
                .keyboardShortcut("[", modifiers: [.command, .option])
            Divider()
            Button("Manage Categories…") { appState.perform(.manageCategories) }
            Divider()
            Button("AI…") { appState.perform(.showAI) }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            Button(appState.isInspectorPresented ? "Hide Inspector" : "Show Inspector") {
                appState.perform(.toggleInspector)
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            Divider()
            Button("Load Sample Timeline") { appState.perform(.loadSample) }
            Button("Load Comparison Sample") { appState.perform(.loadComparisonSample) }
            Button("Load Three-Timeline Sample") { appState.perform(.loadThreeTimelineSample) }
        }
    }
}
