import Foundation

/// Shared app identity and release configuration (used by core probe UA and app shell).
public enum AppMetadata {
    public static let version = "0.1.0"
    public static let bundleIdentifier = "com.robzilla1738.localhostbar"
    public static let productName = "LocalhostBar"
    public static let githubOwner = "robzilla1738"
    public static let githubRepo = "localhostbar"
    public static let githubURL = URL(string: "https://github.com/robzilla1738/localhostbar")!
    public static let releasesURL = URL(string: "https://github.com/robzilla1738/localhostbar/releases")!
    /// Public Sparkle appcast (latest release asset `appcast.xml`).
    public static let appcastURL = URL(
        string: "https://github.com/robzilla1738/localhostbar/releases/latest/download/appcast.xml"
    )!
    /// EdDSA public key for Sparkle update signatures (private key is never shipped).
    public static let sparklePublicEDKey = "jxkUZBAWGtpJOQwypgrgdPVqi1afRE1vFAd32uSU10I="
    public static let copyright = "Copyright © 2026"
}
