import LocalhostCore
import SwiftUI

@main
struct LocalhostBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = LocalhostModel()
    @StateObject private var preferences = LocalhostPreferences.shared

    var body: some Scene {
        MenuBarExtra {
            LocalhostPopover(model: model, preferences: preferences)
        } label: {
            Image(systemName: model.menuIcon)
                .help(model.menuTooltip)
                .accessibilityLabel(model.menuTooltip)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView(model: model, preferences: preferences)
                .frame(width: 360, height: 280)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
