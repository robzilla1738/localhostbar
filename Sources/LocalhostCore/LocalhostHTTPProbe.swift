import Foundation

public struct LocalhostHTTPProbe: Sendable {
    private let timeout: TimeInterval
    private let session: URLSession

    public init(timeout: TimeInterval = 0.8) {
        self.timeout = timeout

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpMaximumConnectionsPerHost = 8
        self.session = URLSession(configuration: configuration)
    }

    /// Annotate instances with HTTP probe results, reusing cached probes when fingerprints match.
    public func annotate(
        _ instances: [LocalhostInstance],
        previous: [LocalhostInstance] = []
    ) async -> [LocalhostInstance] {
        let previousByFingerprint = Dictionary(
            previous.map { ($0.fingerprint, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return await withTaskGroup(of: LocalhostInstance.self) { group in
            for instance in instances {
                group.addTask {
                    if instance.category == .system {
                        return instance
                    }

                    if let prior = previousByFingerprint[instance.fingerprint],
                       prior.httpProbe != nil || prior.category == .system {
                        // Reuse prior probe when process identity is unchanged.
                        if let probe = prior.httpProbe {
                            return instance.withHTTPProbe(probe)
                        }
                        return instance
                    }

                    let result = await self.probe(instance)
                    return instance.withHTTPProbe(result)
                }
            }

            var annotated: [LocalhostInstance] = []
            for await instance in group {
                annotated.append(instance)
            }

            return Self.sort(annotated)
        }
    }

    public static func sort(_ instances: [LocalhostInstance]) -> [LocalhostInstance] {
        instances.sorted { lhs, rhs in
            if lhs.isHiddenByDefault != rhs.isHiddenByDefault {
                return !lhs.isHiddenByDefault
            }

            if lhs.category != rhs.category {
                return lhs.category.sortOrder < rhs.category.sortOrder
            }

            if lhs.displayName != rhs.displayName {
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }

            return lhs.port < rhs.port
        }
    }

    private func probe(_ instance: LocalhostInstance) async -> HTTPProbeResult? {
        if let result = await probe(instance, scheme: "http") {
            return result
        }

        return await probe(instance, scheme: "https")
    }

    private func probe(_ instance: LocalhostInstance, scheme: String) async -> HTTPProbeResult? {
        guard let url = URL(string: "\(scheme)://localhost:\(instance.port)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("bytes=0-65535", forHTTPHeaderField: "Range")
        request.setValue("LocalhostBar/\(AppMetadata.version)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout

        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                return nil
            }

            let contentType = response.value(forHTTPHeaderField: "Content-Type")
            return HTTPProbeResult(
                scheme: scheme,
                statusCode: response.statusCode,
                contentType: contentType,
                server: response.value(forHTTPHeaderField: "Server"),
                title: Self.title(from: data, contentType: contentType)
            )
        } catch {
            return nil
        }
    }

    static func title(from data: Data, contentType: String?) -> String? {
        if let contentType,
           !contentType.localizedCaseInsensitiveContains("html") {
            return nil
        }

        guard let html = String(data: data.prefix(131_072), encoding: .utf8)
            ?? String(data: data.prefix(131_072), encoding: .isoLatin1) else {
            return nil
        }

        let pattern = #"<title[^>]*>(.*?)</title>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges > 1,
              let titleRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        return decodeHTMLEntities(String(html[titleRange]))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}

public enum AppMetadata {
    public static let version = "0.1.0"
    public static let bundleIdentifier = "com.robzilla1738.localhostbar"
    public static let productName = "LocalhostBar"
    public static let githubURL = URL(string: "https://github.com/robzilla1738/localhostbar")!
    public static let copyright = "Copyright © 2026"
}

private extension LocalhostCategory {
    var sortOrder: Int {
        switch self {
        case .web:
            return 0
        case .api:
            return 1
        case .service:
            return 2
        case .system:
            return 3
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
