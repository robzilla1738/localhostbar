import AppKit
import Darwin
import Foundation
import LocalhostCore

@MainActor
final class LocalhostModel: ObservableObject {
    @Published private(set) var allInstances: [LocalhostInstance] = []
    @Published private(set) var isScanning = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var showingPreferences = false

    private let scanner = LocalhostScanner()
    private let probe = LocalhostHTTPProbe()
    private let preferences: LocalhostPreferences
    private var refreshTask: Task<Void, Never>?
    private var refreshLoopTask: Task<Void, Never>?
    private var pendingRefresh = false

    init(preferences: LocalhostPreferences = .shared) {
        self.preferences = preferences
        refresh()
        startRefreshLoop()
    }

    deinit {
        refreshLoopTask?.cancel()
        refreshTask?.cancel()
    }

    var displayedInstances: [LocalhostInstance] {
        LocalhostDisplayFilter.displayed(
            allInstances,
            showBackgroundServices: preferences.showBackgroundServices
        )
    }

    var hiddenCount: Int {
        max(0, allInstances.count - displayedInstances.count)
    }

    var menuTitle: String {
        // Icon-only menu bar item.
        ""
    }

    var menuIcon: String {
        displayedInstances.isEmpty ? "network.slash" : "network"
    }

    var menuTooltip: String {
        let count = displayedInstances.count
        if count == 0 {
            return "\(AppMetadata.productName) — no open ports"
        }
        if count == 1 {
            return "\(AppMetadata.productName) — 1 port"
        }
        return "\(AppMetadata.productName) — \(count) ports"
    }

    func startRefreshLoop() {
        refreshLoopTask?.cancel()
        refreshLoopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let seconds = self?.preferences.refreshInterval ?? 4
                try? await Task.sleep(for: .seconds(seconds))
                self?.refresh()
            }
        }
    }

    func refresh() {
        if isScanning {
            pendingRefresh = true
            return
        }

        isScanning = true
        errorMessage = nil
        let scanner = scanner
        let probe = probe
        let previous = allInstances

        refreshTask = Task {
            do {
                let nextInstances = try await Task.detached(priority: .utility) {
                    try scanner.scan()
                }.value
                let annotatedInstances = await probe.annotate(nextInstances, previous: previous)

                if !Task.isCancelled {
                    allInstances = annotatedInstances
                    lastUpdated = Date()
                }
            } catch {
                errorMessage = error.localizedDescription
            }

            isScanning = false

            if pendingRefresh {
                pendingRefresh = false
                refresh()
            }
        }
    }

    func open(_ instance: LocalhostInstance) {
        guard instance.isOpenable, let url = instance.url else { return }
        NSWorkspace.shared.open(url)
    }

    func copyURL(_ instance: LocalhostInstance) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(instance.copyString, forType: .string)
    }

    func copyPort(_ instance: LocalhostInstance) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(instance.port)", forType: .string)
    }

    func stop(_ instance: LocalhostInstance) {
        guard instance.canStopSafely else {
            errorMessage = "\(instance.displayName) is a background service managed by macOS or another app."
            return
        }

        let result = kill(instance.pid, SIGTERM)

        if result == 0 {
            allInstances.removeAll { $0.pid == instance.pid }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                refresh()
            }
        } else {
            let message = String(cString: strerror(errno))
            errorMessage = "Could not stop \(instance.displayName): \(message)"
        }
    }

    func revealInActivityMonitor(_ instance: LocalhostInstance) {
        // Best-effort: open Activity Monitor; user can search by PID.
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        copyPort(instance) // not ideal; copy PID instead for search
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(instance.pid)", forType: .string)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
