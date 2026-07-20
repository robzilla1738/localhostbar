import LocalhostCore
import SwiftUI

@main
struct LocalhostBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = LocalhostModel()
    @StateObject private var preferences = LocalhostPreferences.shared
    @StateObject private var updates = UpdateController.shared

    var body: some Scene {
        MenuBarExtra {
            LocalhostPopover(
                model: model,
                preferences: preferences,
                updates: updates
            )
        } label: {
            Image(systemName: model.menuIcon)
                .help(model.menuTooltip)
                .accessibilityLabel(model.menuTooltip)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView(
                model: model,
                preferences: preferences,
                updates: updates
            )
            .frame(width: 380, height: 320)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        // Touch updater so Sparkle schedules automatic checks after launch.
        _ = UpdateController.shared
    }
}
