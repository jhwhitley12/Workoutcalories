import AppKit
import SwiftUI

@main
struct StockScreenerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = ScreenerModel()

    var body: some Scene {
        WindowGroup("Stock Screener") {
            ContentView()
                .environment(model)
                .frame(minWidth: 1000, minHeight: 600)
        }
        .defaultSize(width: 1400, height: 820)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh Data") {
                    model.refresh()
                }
                .keyboardShortcut("r")
                .disabled(model.isLoading)

                Button("Export Results as CSV…") {
                    model.exportCSV()
                }
                .keyboardShortcut("e")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched with `swift run`, which starts the app without a bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
