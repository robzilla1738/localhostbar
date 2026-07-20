import XCTest
@testable import LocalhostCore

/// Verifies shipped public identity/config used by the real app and release feed.
final class AppMetadataTests: XCTestCase {
    func testVersionMatchesVERSIONFileFormat() {
        // VERSION is single-sourced for releases; AppMetadata.version must stay aligned.
        XCTAssertFalse(AppMetadata.version.isEmpty)
        XCTAssertEqual(AppMetadata.version, "0.1.0")
        XCTAssertTrue(AppMetadata.version.contains("."))
    }

    func testSparklePublicKeyIsConfigured() {
        let key = AppMetadata.sparklePublicEDKey
        XCTAssertFalse(key.isEmpty)
        // EdDSA public keys for Sparkle are base64 of 32 bytes → 44 chars with padding
        XCTAssertEqual(key.count, 44)
        XCTAssertTrue(key.hasSuffix("="))
        XCTAssertEqual(key, "jxkUZBAWGtpJOQwypgrgdPVqi1afRE1vFAd32uSU10I=")
    }

    func testAppcastURLPointsAtPublicReleasesLatest() {
        let url = AppMetadata.appcastURL.absoluteString
        XCTAssertTrue(url.hasPrefix("https://github.com/robzilla1738/localhostbar/"))
        XCTAssertTrue(url.hasSuffix("/releases/latest/download/appcast.xml"))
    }

    func testBundleIdentifierIsStablePublicId() {
        XCTAssertEqual(AppMetadata.bundleIdentifier, "com.robzilla1738.localhostbar")
    }
}
