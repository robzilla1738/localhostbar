import Darwin
import Foundation

public struct LocalhostInstance: Identifiable, Equatable, Sendable {
    public let id: String
    public let pid: Int32
    public let uid: UInt32?
    public let command: String
    public let commandLine: String?
    public let currentDirectory: String?
    public let projectName: String?
    public let packageName: String?
    public let host: String
    public let port: Int
    public let httpProbe: HTTPProbeResult?

    public init(
        pid: Int32,
        uid: UInt32?,
        command: String,
        commandLine: String?,
        currentDirectory: String?,
        projectName: String? = nil,
        packageName: String? = nil,
        host: String,
        port: Int,
        httpProbe: HTTPProbeResult? = nil
    ) {
        self.pid = pid
        self.uid = uid
        self.command = command
        self.commandLine = commandLine
        self.currentDirectory = currentDirectory
        self.projectName = projectName
        self.packageName = packageName
        self.host = host
        self.port = port
        self.httpProbe = httpProbe
        id = "\(pid)-\(port)"
    }

    /// Stable identity used to reuse HTTP probe results across refreshes.
    public var fingerprint: String {
        "\(pid)|\(port)|\(command)|\(commandLine ?? "")"
    }

    public var url: URL? {
        URL(string: "\(httpProbe?.scheme ?? "http")://localhost:\(port)")
    }

    public var copyString: String {
        if isOpenable, let url {
            return url.absoluteString
        }
        return "localhost:\(port)"
    }

    public var displayName: String {
        if let title = httpProbe?.usableTitle, prefersHTTPTitle {
            return title
        }

        if let knownServiceName {
            return knownServiceName
        }

        if let projectName = usefulProjectName {
            return projectName
        }

        if let packageName = packageDisplayName {
            return packageName
        }

        return normalizedCommand
    }

    public var detail: String {
        let descriptor: String
        switch category {
        case .web:
            descriptor = "Web"
        case .api:
            descriptor = "API"
        case .service:
            descriptor = "Service"
        case .system:
            descriptor = "Background"
        }

        if displayName == normalizedCommand {
            return "localhost:\(port) · \(descriptor)"
        }

        return "localhost:\(port) · \(descriptor) · \(normalizedCommand)"
    }

    public var portLabel: String {
        ":\(port)"
    }

    public var category: LocalhostCategory {
        if isProtectedProcess {
            return .system
        }

        guard let httpProbe else {
            return .service
        }

        if httpProbe.isBrowserPage {
            return .web
        }

        return .api
    }

    public var isHiddenByDefault: Bool {
        category == .system || (httpProbe == nil && !isLikelyDevelopmentProcess)
    }

    public var isOpenable: Bool {
        httpProbe != nil
    }

    public var canStopSafely: Bool {
        guard !isProtectedProcess else { return false }

        if let uid, uid != getuid() {
            return false
        }

        return true
    }

    public func withHTTPProbe(_ probe: HTTPProbeResult?) -> LocalhostInstance {
        LocalhostInstance(
            pid: pid,
            uid: uid,
            command: command,
            commandLine: commandLine,
            currentDirectory: currentDirectory,
            projectName: projectName,
            packageName: packageName,
            host: host,
            port: port,
            httpProbe: probe
        )
    }

    private var normalizedCommand: String {
        command
            .replacingOccurrences(of: "\\x20", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var prefersHTTPTitle: Bool {
        guard let httpProbe, httpProbe.isBrowserPage else { return false }
        return true
    }

    private var packageDisplayName: String? {
        guard let packageName else { return nil }
        let strippedScope = packageName.split(separator: "/").last.map(String.init) ?? packageName
        return strippedScope.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private var usefulProjectName: String? {
        projectName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private var knownServiceName: String? {
        let command = normalizedCommand.lowercased()
        let line = commandLine?.lowercased() ?? ""

        if command == "controlcenter" {
            if port == 5000 || port == 7000 {
                return "AirPlay Receiver"
            }

            return "Control Center"
        }

        if command == "rapportd" {
            return "Apple Continuity"
        }

        if command == "com.docker.backend" || command.contains("docker") {
            if port == 5432 {
                return "Postgres (Docker)"
            }
            if port == 6379 {
                return "Redis (Docker)"
            }
            if port == 27017 {
                return "MongoDB (Docker)"
            }
            if port == 3306 {
                return "MySQL (Docker)"
            }

            return "Docker"
        }

        if command.contains("cursor helper") {
            return "Cursor Extension Host"
        }

        if command.contains("adoberesourcesynchronizer") {
            return "Adobe Sync"
        }

        if command.contains("adobe desktop service") {
            return "Adobe Desktop Service"
        }

        if command == "agent-server", line.contains("/applications/dia.app/") {
            return "Dia Agent Server"
        }

        if command == "ollama" || line.contains("ollama serve") {
            return "Ollama"
        }

        if command.contains("openclaw") || line.contains("openclaw-gateway") {
            return "OpenClaw Gateway"
        }

        return nil
    }

    private var isLikelyDevelopmentProcess: Bool {
        let line = commandLine?.lowercased() ?? ""
        let command = normalizedCommand.lowercased()

        let markers = [
            "next-server",
            "vite",
            "webpack",
            "astro",
            "nuxt",
            "remix",
            "rails server",
            "python -m http.server",
            "python3 -m http.server",
            "http.server",
            "uvicorn",
            "gunicorn",
            "django",
            "flask",
            "php -s",
            "cargo run",
            "go run",
            "http-server",
            "live-server",
            "parcel",
            "esbuild",
            "wrangler",
            "bun",
            "deno",
            "tsx",
            "nodemon",
            "ollama serve",
            "openclaw-gateway"
        ]

        return markers.contains { line.contains($0) || command.contains($0) }
    }

    private var isProtectedProcess: Bool {
        let command = normalizedCommand.lowercased()
        let line = commandLine?.lowercased() ?? ""
        let cwd = currentDirectory?.lowercased() ?? ""

        if command == "controlcenter" || command == "rapportd" {
            return true
        }

        if command.contains("adobe") || command.contains("cursor helper") || command == "com.docker.backend" {
            return true
        }

        let protectedPathMarkers = [
            "/system/library/",
            "/usr/libexec/",
            "/applications/adobe ",
            "/library/application support/adobe/",
            "/applications/docker.app/",
            "/applications/dia.app/",
            "/library/containers/com.docker.docker/",
            "/library/application support/dia/"
        ]

        return protectedPathMarkers.contains { marker in
            line.contains(marker) || cwd.contains(marker)
        }
    }
}

public struct ProcessDetails: Sendable {
    public let commandLine: String?
    public let currentDirectory: String?
    public let projectName: String?
    public let packageName: String?

    public init(
        commandLine: String?,
        currentDirectory: String?,
        projectName: String? = nil,
        packageName: String? = nil
    ) {
        self.commandLine = commandLine
        self.currentDirectory = currentDirectory
        self.projectName = projectName ?? Self.inferredProjectName(from: currentDirectory)
        self.packageName = packageName
    }

    private static func inferredProjectName(from currentDirectory: String?) -> String? {
        guard let currentDirectory else { return nil }
        let trimmed = currentDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != "/", !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        let excludedMarkers = [
            "/library/containers/",
            "/library/application support/",
            "/applications/",
            "/system/",
            "/usr/"
        ]

        guard !excludedMarkers.contains(where: { lower.contains($0) }) else {
            return nil
        }

        return URL(fileURLWithPath: trimmed).lastPathComponent.nonEmpty
    }
}

public enum LocalhostCategory: String, Sendable, CaseIterable {
    case web
    case api
    case service
    case system
}

public struct HTTPProbeResult: Equatable, Sendable {
    public let scheme: String
    public let statusCode: Int
    public let contentType: String?
    public let server: String?
    public let title: String?

    public init(
        scheme: String,
        statusCode: Int,
        contentType: String?,
        server: String?,
        title: String?
    ) {
        self.scheme = scheme
        self.statusCode = statusCode
        self.contentType = contentType
        self.server = server
        self.title = title
    }

    public var isBrowserPage: Bool {
        if usableTitle != nil {
            return true
        }

        return contentType?.localizedCaseInsensitiveContains("text/html") == true
    }

    var usableTitle: String? {
        guard let title else { return nil }

        let trimmed = title
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 2 else { return nil }

        let lower = trimmed.lowercased()
        let genericTitles = [
            "localhost",
            "index",
            "vite + react",
            "vite + react + ts",
            "create next app"
        ]

        guard !genericTitles.contains(lower) else { return nil }
        return trimmed
    }
}

public enum LocalhostDisplayFilter: Sendable {
    /// Filters instances for the menu list.
    public static func displayed(
        _ instances: [LocalhostInstance],
        showBackgroundServices: Bool
    ) -> [LocalhostInstance] {
        if showBackgroundServices {
            return instances
        }
        return instances.filter { !$0.isHiddenByDefault }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
