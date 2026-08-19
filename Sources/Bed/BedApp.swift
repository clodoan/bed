import AppKit
import SwiftUI

@main
struct BedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = BedModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView(model: model)
        } label: {
            Text("🛏️")
                .accessibilityLabel("Bed")
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Bed") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        PixelFont.register()
    }
}
