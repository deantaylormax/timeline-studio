import SwiftUI
import SwiftData

@main
struct TimelineStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @State private var subscription = SubscriptionCenter()

    var body: some Scene {
        Window("Timeline Studio", id: "main") {
            ContentView()
                .environment(appState)
                .environment(subscription)
                .frame(minWidth: 860, minHeight: 580)
        }
        .defaultSize(width: 1280, height: 840)
        .modelContainer(for: [TimelineEvent.self, CustomCategory.self, TimelineDivider.self], isUndoEnabled: true)
        .commands {
            TimelineCommands(appState: appState)
            SidebarCommands()
            ToolbarCommands()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if SnapshotHarness.isRequested {
            DispatchQueue.main.async {
                SnapshotHarness.run()
                NSApp.terminate(nil)
            }
        }
        if SampleDividerCleanup.isRequested {
            RunLoop.main.perform {
                SampleDividerCleanup.run()
                NSApp.terminate(nil)
            }
        }
        if DividerTest.isRequested {
            RunLoop.main.perform {
                DividerTest.run()
                NSApp.terminate(nil)
            }
        }
        if LaneTagTest.isRequested {
            // Run from the run loop rather than the main queue, so the app's own main-queue work
            // (focus changes and the like) can still happen while the test waits.
            RunLoop.main.perform {
                LaneTagTest.run()
                NSApp.terminate(nil)
            }
        }
        if PresentationTrace.isRequested {
            DispatchQueue.main.async {
                PresentationTrace.run()
                NSApp.terminate(nil)
            }
        }
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
