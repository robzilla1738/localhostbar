import Foundation
import ServiceManagement
import SwiftUI

enum PreferenceKey {
    static let showBackgroundServices = "showBackgroundServices"
    static let refreshIntervalSeconds = "refreshIntervalSeconds"
}

@MainActor
final class LocalhostPreferences: ObservableObject {
    static let shared = LocalhostPreferences()

    @Published var showBackgroundServices: Bool {
        didSet {
            UserDefaults.standard.set(showBackgroundServices, forKey: PreferenceKey.showBackgroundServices)
        }
    }

    @Published var refreshIntervalSeconds: Int {
        didSet {
            let clamped = max(2, min(refreshIntervalSeconds, 60))
            if clamped != refreshIntervalSeconds {
                refreshIntervalSeconds = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: PreferenceKey.refreshIntervalSeconds)
        }
    }

    var refreshInterval: TimeInterval {
        TimeInterval(max(2, min(refreshIntervalSeconds, 60)))
    }

    init() {
        let defaults = UserDefaults.standard
        self.showBackgroundServices = defaults.bool(forKey: PreferenceKey.showBackgroundServices)
        let interval = defaults.object(forKey: PreferenceKey.refreshIntervalSeconds) as? Int ?? 4
        self.refreshIntervalSeconds = max(2, min(interval, 60))
    }

    var launchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @discardableResult
    func setLaunchAtLogin(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            objectWillChange.send()
            return true
        } catch {
            NSLog("Launch at login change failed: \(error.localizedDescription)")
            objectWillChange.send()
            return false
        }
    }
}
