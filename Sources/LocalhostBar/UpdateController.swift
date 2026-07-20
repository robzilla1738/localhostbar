import AppKit
import Foundation
import Sparkle

/// Owns the Sparkle updater for LocalhostBar.
@MainActor
final class UpdateController: NSObject, ObservableObject {
    static let shared = UpdateController()

    private let updaterController: SPUStandardUpdaterController

    private override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
