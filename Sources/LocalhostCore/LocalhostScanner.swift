import Foundation

public struct LocalhostScanner: Sendable {
    public typealias DetailsProvider = @Sendable (Int32) -> ProcessDetails

    private let detailsProvider: DetailsProvider

    public init() {
        detailsProvider = Self.defaultDetails(for:)
    }

    public init(detailsProvider: @escaping DetailsProvider) {
        self.detailsProvider = detailsProvider
    }

    public func scan() throws -> [LocalhostInstance] {
        let output: String
        do {
            output = try Self.run(
                executable: "/usr/sbin/lsof",
                arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcun"]
            )
        } catch ScannerError.commandFailed(_, 1, _) {
            return []
        }

        return parseLsofFields(output)
    }

    public func parseLsofFields(_ output: String) -> [LocalhostInstance] {
        let records = Self.records(from: output)
        var instancesByID: [String: LocalhostInstance] = [:]

        for record in records {
            guard let pid = record.pid else { continue }
            let details = detailsProvider(pid)

            for endpoint in record.endpoints {
                guard let parsed = Self.parseEndpoint(endpoint) else { continue }

                let instance = LocalhostInstance(
                    pid: pid,
                    uid: record.uid,
                    command: record.command ?? "Process \(pid)",
                    commandLine: details.commandLine,
                    currentDirectory: details.currentDirectory,
                    projectName: details.projectName,
                    packageName: details.packageName,
                    host: parsed.host,
                    port: parsed.port
                )

                instancesByID[instance.id] = instance
            }
        }

        return instancesByID.values.sorted { lhs, rhs in
            if lhs.port == rhs.port {
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }

            return lhs.port < rhs.port
        }
    }

    static func parseEndpoint(_ endpoint: String) -> (host: String, port: Int)? {
        guard !endpoint.contains("->"),
              let separator = endpoint.lastIndex(of: ":") else {
            return nil
        }

        let rawHost = String(endpoint[..<separator])
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let rawPort = endpoint[endpoint.index(after: separator)...]
        let portDigits = rawPort.prefix { $0.isNumber }

        guard let port = Int(portDigits), port > 0 else {
            return nil
        }

        let host = rawHost.isEmpty ? "*" : rawHost
        guard Self.isLocalhostReachableHost(host) else {
            return nil
        }

        return (host, port)
    }

    private static func isLocalhostReachableHost(_ host: String) -> Bool {
        switch host.lowercased() {
        case "*", "localhost", "127.0.0.1", "0.0.0.0", "::1", "::":
            return true
        default:
            return host.hasPrefix("127.")
        }
    }

    private static func records(from output: String) -> [LsofRecord] {
        var records: [LsofRecord] = []
        var current = LsofRecord()

        func flushCurrent() {
            guard current.pid != nil else { return }
            records.append(current)
            current = LsofRecord()
        }

        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())

            switch field {
            case "p":
                flushCurrent()
                current.pid = Int32(value)
            case "c":
                current.command = value
            case "u":
                current.uid = UInt32(value)
            case "n":
                current.endpoints.append(value)
            default:
                continue
            }
        }

        flushCurrent()
        return records
    }

    private static func defaultDetails(for pid: Int32) -> ProcessDetails {
        let commandLine = commandLine(for: pid)
        let currentDirectory = currentDirectory(for: pid)
        let projectRoot = projectRoot(currentDirectory: currentDirectory, commandLine: commandLine)

        return ProcessDetails(
            commandLine: commandLine,
            currentDirectory: currentDirectory,
            projectName: projectRoot.map { URL(fileURLWithPath: $0).lastPathComponent },
            packageName: projectRoot.flatMap { packageName(in: $0) }
        )
    }

    private static func commandLine(for pid: Int32) -> String? {
        try? run(
            executable: "/bin/ps",
            arguments: ["-p", "\(pid)", "-o", "command="]
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .nonEmpty
    }

    private static func currentDirectory(for pid: Int32) -> String? {
        guard let output = try? run(
            executable: "/usr/sbin/lsof",
            arguments: ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]
        ) else {
            return nil
        }

        return output
            .split(separator: "\n")
            .compactMap { line -> String? in
                guard line.first == "n" else { return nil }
                return String(line.dropFirst())
            }
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    /// Walk up from cwd (or executable dir) looking for project markers.
    private static func projectRoot(currentDirectory: String?, commandLine: String?) -> String? {
        var candidates: [String] = []

        if let currentDirectory, isUsefulProjectPath(currentDirectory) {
            candidates.append(currentDirectory)
        }

        if let executablePath = executablePath(from: commandLine),
           isUsefulProjectPath(executablePath) {
            candidates.append(URL(fileURLWithPath: executablePath).deletingLastPathComponent().path)
        }

        for start in candidates {
            if let root = walkForProjectRoot(startingAt: start) {
                return root
            }
        }

        // Fall back to first useful path even without markers.
        return candidates.first
    }

    private static let projectMarkers = [
        "package.json",
        "Cargo.toml",
        "go.mod",
        "pyproject.toml",
        "Package.swift",
        "Gemfile",
        "composer.json",
        "mix.exs",
        "pom.xml",
        "build.gradle",
        "build.gradle.kts"
    ]

    private static func walkForProjectRoot(startingAt path: String, maxLevels: Int = 4) -> String? {
        var url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        // If path is a file, start from its directory.
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            url = url.deletingLastPathComponent()
        }

        for _ in 0..<maxLevels {
            let pathString = url.path
            guard isUsefulProjectPath(pathString) else { return nil }

            for marker in projectMarkers {
                let markerPath = url.appendingPathComponent(marker).path
                if fileManager.fileExists(atPath: markerPath) {
                    return pathString
                }
            }

            let parent = url.deletingLastPathComponent()
            if parent.path == url.path || parent.path == "/" {
                break
            }
            url = parent
        }

        return nil
    }

    private static func executablePath(from commandLine: String?) -> String? {
        guard let commandLine = commandLine?.trimmingCharacters(in: .whitespacesAndNewlines),
              commandLine.hasPrefix("/") else {
            return nil
        }

        if let spaceIndex = commandLine.firstIndex(of: " ") {
            return String(commandLine[..<spaceIndex])
        }

        return commandLine
    }

    private static func isUsefulProjectPath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != "/", !trimmed.isEmpty else { return false }

        let lower = trimmed.lowercased()
        let excludedMarkers = [
            "/library/containers/",
            "/library/application support/",
            "/applications/",
            "/system/",
            "/usr/"
        ]

        return !excludedMarkers.contains { lower.contains($0) }
    }

    private static func packageName(in projectRoot: String) -> String? {
        let root = URL(fileURLWithPath: projectRoot)

        // Node
        if let name = readJSONName(at: root.appendingPathComponent("package.json")) {
            return name
        }

        // Python pyproject.toml — crude name = "…" parse
        let pyproject = root.appendingPathComponent("pyproject.toml")
        if let text = try? String(contentsOf: pyproject, encoding: .utf8),
           let name = tomlStringValue(text, key: "name") {
            return name
        }

        // Cargo.toml
        let cargo = root.appendingPathComponent("Cargo.toml")
        if let text = try? String(contentsOf: cargo, encoding: .utf8),
           let name = tomlStringValue(text, key: "name") {
            return name
        }

        return nil
    }

    private static func readJSONName(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = object["name"] as? String else {
            return nil
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private static func tomlStringValue(_ text: String, key: String) -> String? {
        // Match: name = "value"  (first occurrence; good enough for package roots)
        let pattern = #"^\s*"# + NSRegularExpression.escapedPattern(for: key) + #"\s*=\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private static func run(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0, data.isEmpty {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? "Command failed"
            throw ScannerError.commandFailed(executable, process.terminationStatus, message)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }
}

private struct LsofRecord {
    var pid: Int32?
    var uid: UInt32?
    var command: String?
    var endpoints: [String] = []
}

public enum ScannerError: Error, LocalizedError {
    case commandFailed(String, Int32, String)

    public var errorDescription: String? {
        switch self {
        case let .commandFailed(command, status, message):
            return "\(command) exited with status \(status): \(message)"
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
