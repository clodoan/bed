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
            Image(systemName: "house.fill")
                .accessibilityLabel("Lo fi house")
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Lo fi house") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        PixelFont.register()
        if Snapshot.requested {
            Task { @MainActor in
                await Snapshot.write()
                NSApp.terminate(nil)
            }
            return
        }
        NSApp.setActivationPolicy(.accessory)
    }
}
