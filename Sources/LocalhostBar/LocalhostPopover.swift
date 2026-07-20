import AppKit
import LocalhostCore
import SwiftUI

struct LocalhostPopover: View {
    @ObservedObject var model: LocalhostModel
    @ObservedObject var preferences: LocalhostPreferences
    @ObservedObject var updates: UpdateController

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if model.displayedInstances.isEmpty {
                EmptyStateView(
                    isScanning: model.isScanning,
                    hiddenCount: model.hiddenCount,
                    showBackground: preferences.showBackgroundServices,
                    revealBackground: {
                        preferences.showBackgroundServices = true
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(model.displayedInstances) { instance in
                            LocalhostRow(
                                instance: instance,
                                open: { model.open(instance) },
                                copyURL: { model.copyURL(instance) },
                                copyPort: { model.copyPort(instance) },
                                stop: { model.stop(instance) },
                                reveal: { model.revealInActivityMonitor(instance) }
                            )
                        }
                    }
                    .padding(6)
                }
                .frame(height: listHeight)
            }

            Divider()

            footer
        }
        .frame(width: 360)
        .background {
            Button("") { model.refresh() }
                .keyboardShortcut("r", modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
        }
    }

    private var listHeight: CGFloat {
        let rowHeight: CGFloat = 52
        let verticalPadding: CGFloat = 12
        let count = CGFloat(model.displayedInstances.count)
        return min(max((count * rowHeight) + verticalPadding, 76), 420)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label(AppMetadata.productName, systemImage: "network")
                .font(.headline)
                .labelStyle(.titleAndIcon)

            Spacer()

            countBadge

            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(model.isScanning)
            .help("Refresh (⌘R)")
            .keyboardShortcut("r", modifiers: .command)

            Button {
                openPreferences()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Preferences")
            .contextMenu {
                Button("Check for Updates…") {
                    updates.checkForUpdates()
                }
                .disabled(!updates.canCheckForUpdates)
            }

            Button {
                model.quit()
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var countBadge: some View {
        Group {
            if model.hiddenCount > 0, !preferences.showBackgroundServices {
                Text("\(model.displayedInstances.count) · \(model.hiddenCount) hidden")
            } else {
                Text("\(model.displayedInstances.count)")
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private var footer: some View {
        HStack {
            if let lastUpdated = model.lastUpdated {
                Text(lastUpdated, style: .time)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(isOn: $preferences.showBackgroundServices) {
                Text("Background")
                    .font(.caption2)
            }
            .toggleStyle(.checkbox)
            .help("Show system and app-managed ports")

            if model.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 4)
            }
        }
        .frame(height: 28)
        .padding(.horizontal, 12)
    }

    private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct LocalhostRow: View {
    let instance: LocalhostInstance
    let open: () -> Void
    let copyURL: () -> Void
    let copyPort: () -> Void
    let stop: () -> Void
    let reveal: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            if instance.isOpenable {
                Button(action: open) {
                    rowContent
                }
                .buttonStyle(.plain)
                .help("Open \(instance.url?.absoluteString ?? "localhost:\(instance.port)")")
            } else {
                rowContent
            }

            Spacer(minLength: 0)

            Text(instance.portLabel)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.06), in: Capsule())
                .help("Port \(instance.port)")

            Button(action: copyURL) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(isHovering ? .primary : .secondary)
            .help("Copy \(instance.copyString)")
            .opacity(isHovering ? 1 : 0.55)

            if instance.canStopSafely {
                Button(role: .destructive, action: stop) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isHovering ? .red : .secondary)
                .help("Stop \(instance.displayName)")
                .accessibilityLabel("Stop \(instance.displayName)")
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 18, height: 18)
                    .help("Managed by macOS or another app")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.07) : Color.clear)
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            if instance.isOpenable {
                Button("Open in Browser", action: open)
            }
            Button("Copy URL", action: copyURL)
            Button("Copy Port", action: copyPort)
            Button("Copy PID") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString("\(instance.pid)", forType: .string)
            }
            Divider()
            Button("Reveal in Activity Monitor", action: reveal)
            if instance.canStopSafely {
                Divider()
                Button("Stop Process", role: .destructive, action: stop)
            }
        }
        .accessibilityLabel("\(instance.displayName), localhost \(instance.port)")
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Image(systemName: instance.category.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(instance.category.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(instance.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(instance.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct EmptyStateView: View {
    let isScanning: Bool
    let hiddenCount: Int
    let showBackground: Bool
    let revealBackground: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isScanning ? "arrow.triangle.2.circlepath" : "network.slash")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)

            Text(emptyTitle)
                .font(.callout)
                .foregroundStyle(.secondary)

            if !isScanning {
                Text(emptySubtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                if hiddenCount > 0, !showBackground {
                    Button("Show \(hiddenCount) background") {
                        revealBackground()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 16)
    }

    private var emptyTitle: String {
        if isScanning {
            return "Scanning…"
        }
        return "No local ports"
    }

    private var emptySubtitle: String {
        if hiddenCount > 0, !showBackground {
            return "No openable dev servers. \(hiddenCount) background service\(hiddenCount == 1 ? "" : "s") hidden."
        }
        return "Start a dev server and it will show up here."
    }
}

private extension LocalhostCategory {
    var symbolName: String {
        switch self {
        case .web:
            return "safari"
        case .api:
            return "curlybraces"
        case .service:
            return "gearshape"
        case .system:
            return "lock.shield"
        }
    }

    var tint: Color {
        switch self {
        case .web:
            return .accentColor
        case .api:
            return .secondary
        case .service:
            return .secondary
        case .system:
            return .secondary
        }
    }
}
