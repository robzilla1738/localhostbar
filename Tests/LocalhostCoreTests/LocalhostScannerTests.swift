import Darwin
import XCTest
@testable import LocalhostCore

final class LocalhostScannerTests: XCTestCase {
    func testParserKeepsLocalhostReachableListenersAndDeduplicatesPorts() {
        let scanner = LocalhostScanner { pid in
            switch pid {
            case 101:
                ProcessDetails(
                    commandLine: "next-server (v16.2.9)",
                    currentDirectory: "/Users/dev/Documents/Vektor"
                )
            case 202:
                ProcessDetails(
                    commandLine: "python3 -m http.server",
                    currentDirectory: "/Users/dev/Code/site"
                )
            default:
                ProcessDetails(commandLine: nil, currentDirectory: nil)
            }
        }

        let output = """
        p101
        cnode
        u501
        f13
        n*:3100
        f14
        n[::]:3100
        p202
        cPython
        u501
        f6
        n127.0.0.1:8000
        p303
        cRemoteOnly
        u501
        f7
        n192.168.1.20:9000
        """

        let instances = scanner.parseLsofFields(output)

        XCTAssertEqual(instances.map(\.port), [3100, 8000])
        XCTAssertEqual(instances[0].displayName, "Vektor")
        XCTAssertEqual(instances[1].displayName, "site")
    }

    func testParserAcceptsLoopbackRange() {
        let scanner = LocalhostScanner { _ in
            ProcessDetails(commandLine: nil, currentDirectory: nil)
        }

        let output = """
        p404
        cDev
        u501
        f9
        n127.10.0.2:5173
        """

        let instances = scanner.parseLsofFields(output)

        XCTAssertEqual(instances.count, 1)
        XCTAssertEqual(instances.first?.url?.absoluteString, "http://localhost:5173")
    }

    func testHTTPTitleBecomesDisplayNameForWebPages() {
        let instance = LocalhostInstance(
            pid: 505,
            uid: 501,
            command: "node",
            commandLine: "next-server (v16.2.9)",
            currentDirectory: "/Users/dev/Documents/Vektor",
            host: "*",
            port: 3100
        )
        .withHTTPProbe(
            HTTPProbeResult(
                scheme: "http",
                statusCode: 200,
                contentType: "text/html; charset=utf-8",
                server: nil,
                title: "Vektor"
            )
        )

        XCTAssertEqual(instance.category, .web)
        XCTAssertEqual(instance.displayName, "Vektor")
        XCTAssertFalse(instance.isHiddenByDefault)
        XCTAssertEqual(instance.url?.absoluteString, "http://localhost:3100")
    }

    func testProtectedSystemServicesAreHiddenAndNotStoppable() {
        let instance = LocalhostInstance(
            pid: 606,
            uid: 501,
            command: "ControlCenter",
            commandLine: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter",
            currentDirectory: "/",
            host: "*",
            port: 5000,
            httpProbe: HTTPProbeResult(
                scheme: "http",
                statusCode: 403,
                contentType: nil,
                server: "AirTunes/980.58.1",
                title: nil
            )
        )

        XCTAssertEqual(instance.category, .system)
        XCTAssertEqual(instance.displayName, "AirPlay Receiver")
        XCTAssertTrue(instance.isHiddenByDefault)
        XCTAssertFalse(instance.canStopSafely)
    }

    func testContextualNamesForCommonBackgroundServices() {
        let docker = LocalhostInstance(
            pid: 607,
            uid: 501,
            command: "com.docker.backend",
            commandLine: "/Applications/Docker.app/Contents/MacOS/com.docker.backend services",
            currentDirectory: "/Users/dev/Library/Containers/com.docker.docker/Data",
            host: "*",
            port: 5432
        )

        let dia = LocalhostInstance(
            pid: 608,
            uid: 501,
            command: "agent-server",
            commandLine: "/Applications/Dia.app/Contents/Resources/agent-server-resources/dist/agent-server --app-name Dia",
            currentDirectory: "/Users/dev/Library/Application Support/Dia/User Data/Profile 1/AgentServer",
            host: "127.0.0.1",
            port: 53129
        )

        let adobe = LocalhostInstance(
            pid: 609,
            uid: 501,
            command: "AdobeResourceSynchronizer",
            commandLine: "/Applications/Adobe Acrobat DC/Adobe Acrobat.app/Contents/Helpers/AdobeResourceSynchronizer.app/Contents/MacOS/AdobeResourceSynchronizer",
            currentDirectory: "/",
            host: "127.0.0.1",
            port: 19292
        )

        XCTAssertEqual(docker.displayName, "Postgres (Docker)")
        XCTAssertEqual(dia.displayName, "Dia Agent Server")
        XCTAssertEqual(adobe.displayName, "Adobe Sync")
    }

    func testDevelopmentExecutablePathCanNameAServiceWhenCwdIsRoot() {
        let scanner = LocalhostScanner { _ in
            ProcessDetails(
                commandLine: "/Users/dev/Code/my-shim/shim-server 11535",
                currentDirectory: "/",
                projectName: "my-shim"
            )
        }

        let output = """
        p707
        cshim-server
        u501
        f4
        n*:11535
        """

        let instance = scanner.parseLsofFields(output).first

        XCTAssertEqual(instance?.displayName, "my-shim")
        XCTAssertFalse(instance?.isHiddenByDefault ?? true)
    }

    func testHTMLTitleExtractionIsWhitespaceAndEntitySafe() {
        let data = Data("""
        <!doctype html>
        <html>
          <head><title>
            Build &amp; Preview
          </title></head>
        </html>
        """.utf8)

        XCTAssertEqual(
            LocalhostHTTPProbe.title(from: data, contentType: "text/html"),
            "Build & Preview"
        )
    }

    func testDisplayFilterHidesBackgroundByDefault() {
        let web = LocalhostInstance(
            pid: 1,
            uid: 501,
            command: "node",
            commandLine: "next-server",
            currentDirectory: "/Users/dev/app",
            host: "*",
            port: 3000,
            httpProbe: HTTPProbeResult(
                scheme: "http",
                statusCode: 200,
                contentType: "text/html",
                server: nil,
                title: "App"
            )
        )

        let system = LocalhostInstance(
            pid: 2,
            uid: 501,
            command: "ControlCenter",
            commandLine: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter",
            currentDirectory: "/",
            host: "*",
            port: 5000
        )

        let hidden = LocalhostDisplayFilter.displayed([web, system], showBackgroundServices: false)
        let shown = LocalhostDisplayFilter.displayed([web, system], showBackgroundServices: true)

        XCTAssertEqual(hidden.map(\.port), [3000])
        XCTAssertEqual(shown.map(\.port), [3000, 5000])
    }

    func testCopyStringPrefersOpenableURL() {
        let openable = LocalhostInstance(
            pid: 1,
            uid: 501,
            command: "node",
            commandLine: "next-server",
            currentDirectory: "/Users/dev/app",
            host: "*",
            port: 3000,
            httpProbe: HTTPProbeResult(
                scheme: "https",
                statusCode: 200,
                contentType: "text/html",
                server: nil,
                title: "App"
            )
        )

        let closed = LocalhostInstance(
            pid: 2,
            uid: 501,
            command: "postgres",
            commandLine: "postgres",
            currentDirectory: "/Users/dev/db",
            host: "127.0.0.1",
            port: 5432
        )

        XCTAssertEqual(openable.copyString, "https://localhost:3000")
        XCTAssertEqual(closed.copyString, "localhost:5432")
    }

    func testOtherUserProcessIsNotStoppable() {
        let instance = LocalhostInstance(
            pid: 99,
            uid: 0,
            command: "node",
            commandLine: "next-server",
            currentDirectory: "/tmp/app",
            host: "*",
            port: 3000
        )

        // Root-owned process should not be stoppable by a normal user session.
        if getuid() != 0 {
            XCTAssertFalse(instance.canStopSafely)
        }
    }

    func testFingerprintStableForProbeCache() {
        let a = LocalhostInstance(
            pid: 10,
            uid: 501,
            command: "node",
            commandLine: "next-server",
            currentDirectory: "/Users/dev/app",
            host: "*",
            port: 3000
        )
        let b = a.withHTTPProbe(
            HTTPProbeResult(scheme: "http", statusCode: 200, contentType: "text/html", server: nil, title: "X")
        )

        XCTAssertEqual(a.fingerprint, b.fingerprint)
    }

    func testLikelyDevMarkersIncludeUvicorn() {
        let instance = LocalhostInstance(
            pid: 11,
            uid: 501,
            command: "python3",
            commandLine: "python3 -m uvicorn main:app --port 8000",
            currentDirectory: "/Users/dev/api",
            host: "127.0.0.1",
            port: 8000
        )

        XCTAssertFalse(instance.isHiddenByDefault)
    }
}
