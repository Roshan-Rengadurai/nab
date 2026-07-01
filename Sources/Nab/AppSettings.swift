import Foundation
import SwiftUI
import NabCore

extension Notification.Name {
    static let nabPreviewToast = Notification.Name("nabPreviewToast")
}

/// Observable settings store. Scalars persist to UserDefaults; the secret
/// access key lives only in the Keychain.
final class AppSettings: ObservableObject {
    private let d = UserDefaults.standard
    private let secretAccount = "secretAccessKey"
    private let nabKeyAccount = "nabLicenseKey"

    // General
    @Published var launchAtLogin: Bool { didSet { d.set(launchAtLogin, forKey: "launchAtLogin") } }
    @Published var soundOnSuccess: Bool { didSet { d.set(soundOnSuccess, forKey: "soundOnSuccess") } }
    @Published var optimisticCopy: Bool { didSet { d.set(optimisticCopy, forKey: "optimisticCopy") } }

    // Storage / provider
    @Published var providerKind: String { didSet { d.set(providerKind, forKey: "providerKind") } }
    @Published var endpoint: String { didSet { d.set(endpoint, forKey: "endpoint") } }
    @Published var bucket: String { didSet { d.set(bucket, forKey: "bucket") } }
    @Published var region: String { didSet { d.set(region, forKey: "region") } }
    @Published var accessKey: String { didSet { d.set(accessKey, forKey: "accessKey") } }
    @Published var publicBase: String { didSet { d.set(publicBase, forKey: "publicBase") } }
    @Published var pathStyle: Bool { didSet { d.set(pathStyle, forKey: "pathStyle") } }

    // Nab hosting (zero-config, hosted by the web app)
    @Published var useNabHosting: Bool { didSet { d.set(useNabHosting, forKey: "useNabHosting") } }
    @Published var nabApiBase: String { didSet { d.set(nabApiBase, forKey: "nabApiBase") } }
    @Published var nabExpiry: String { didSet { d.set(nabExpiry, forKey: "nabExpiry") } } // never|1h|1d|7d|30d

    /// Nab license key — Keychain only, never UserDefaults.
    @Published var nabLicenseKey: String {
        didSet {
            if nabLicenseKey.isEmpty { KeychainStore.shared.delete(account: nabKeyAccount) }
            else { KeychainStore.shared.set(nabLicenseKey, account: nabKeyAccount) }
        }
    }

    /// Selected link-expiry as seconds for the upload request; 0 = never.
    var nabExpirySeconds: Int {
        switch nabExpiry {
        case "never": return 0
        case "1h": return 3600
        case "1d": return 86_400
        case "7d": return 604_800
        default: return 2_592_000 // 30d
        }
    }

    /// Secret access key — read/write straight to Keychain, never UserDefaults.
    @Published var secretKey: String {
        didSet {
            if secretKey.isEmpty { KeychainStore.shared.delete(account: secretAccount) }
            else { KeychainStore.shared.set(secretKey, account: secretAccount) }
        }
    }

    // Capture
    @Published var captureFormat: String { didSet { d.set(captureFormat, forKey: "captureFormat") } }
    @Published var autoDeleteAfterUpload: Bool { didSet { d.set(autoDeleteAfterUpload, forKey: "autoDeleteAfterUpload") } }
    @Published var retinaDownscale: Bool { didSet { d.set(retinaDownscale, forKey: "retinaDownscale") } }

    // Sharing
    @Published var slugLength: Double { didSet { d.set(slugLength, forKey: "slugLength") } }
    @Published var datePrefix: Bool { didSet { d.set(datePrefix, forKey: "datePrefix") } }
    @Published var defaultBurner: Bool { didSet { d.set(defaultBurner, forKey: "defaultBurner") } }

    // Shortcut (tap ⌘ twice)
    @Published var shortcutEnabled: Bool { didSet { d.set(shortcutEnabled, forKey: "shortcutEnabled") } }
    @Published var doubleCmdGap: Double { didSet { d.set(doubleCmdGap, forKey: "doubleCmdGap") } } // ms
    @Published var cmdCtrlCopyImage: Bool { didSet { d.set(cmdCtrlCopyImage, forKey: "cmdCtrlCopyImage") } }

    // Notifications (toast)
    @Published var toastPosition: String { didSet { d.set(toastPosition, forKey: "toastPosition") } }
    @Published var toastDuration: Double { didSet { d.set(toastDuration, forKey: "toastDuration") } } // s
    @Published var toastFollowCursor: Bool { didSet { d.set(toastFollowCursor, forKey: "toastFollowCursor") } }

    // Text highlight share (double-tap Control)
    @Published var textShareEnabled: Bool { didSet { d.set(textShareEnabled, forKey: "textShareEnabled") } }

    /// Hold ⇧ while double-tapping to skip the styled window and share raw text.
    @Published var shiftRawShare: Bool { didSet { d.set(shiftRawShare, forKey: "shiftRawShare") } }

    // Onboarding
    @Published var hasOnboarded: Bool { didSet { d.set(hasOnboarded, forKey: "hasOnboarded") } }

    init() {
        launchAtLogin = d.bool(forKey: "launchAtLogin")
        soundOnSuccess = d.object(forKey: "soundOnSuccess") as? Bool ?? true
        optimisticCopy = d.object(forKey: "optimisticCopy") as? Bool ?? true
        providerKind = d.string(forKey: "providerKind") ?? "r2"
        endpoint = d.string(forKey: "endpoint") ?? ""
        bucket = d.string(forKey: "bucket") ?? ""
        region = d.string(forKey: "region") ?? "auto"
        accessKey = d.string(forKey: "accessKey") ?? ""
        publicBase = d.string(forKey: "publicBase") ?? ""
        pathStyle = d.object(forKey: "pathStyle") as? Bool ?? true
        captureFormat = d.string(forKey: "captureFormat") ?? "png"
        autoDeleteAfterUpload = d.object(forKey: "autoDeleteAfterUpload") as? Bool ?? true
        retinaDownscale = d.bool(forKey: "retinaDownscale")
        slugLength = d.object(forKey: "slugLength") as? Double ?? 10
        datePrefix = d.bool(forKey: "datePrefix")
        defaultBurner = d.bool(forKey: "defaultBurner")
        shortcutEnabled = d.object(forKey: "shortcutEnabled") as? Bool ?? true
        doubleCmdGap = d.object(forKey: "doubleCmdGap") as? Double ?? 300
        cmdCtrlCopyImage = d.object(forKey: "cmdCtrlCopyImage") as? Bool ?? false
        toastPosition = d.string(forKey: "toastPosition") ?? "topTrailing"
        toastDuration = d.object(forKey: "toastDuration") as? Double ?? 2.2
        toastFollowCursor = d.bool(forKey: "toastFollowCursor")
        textShareEnabled = d.object(forKey: "textShareEnabled") as? Bool ?? true
        shiftRawShare = d.object(forKey: "shiftRawShare") as? Bool ?? true
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        secretKey = KeychainStore.shared.get(account: secretAccount) ?? ""
        useNabHosting = d.bool(forKey: "useNabHosting")
        nabApiBase = d.string(forKey: "nabApiBase") ?? "https://trynab.vercel.app"
        nabExpiry = d.string(forKey: "nabExpiry") ?? "30d"
        nabLicenseKey = KeychainStore.shared.get(account: nabKeyAccount) ?? ""
    }

    /// True when enough is configured to attempt an upload.
    var isConfigured: Bool {
        URL(string: endpoint) != nil && !endpoint.isEmpty
            && !bucket.isEmpty && !accessKey.isEmpty && !secretKey.isEmpty
    }

    /// Build a provider from the current settings, or nil if incomplete.
    func makeProvider() -> S3CompatProvider? {
        guard let ep = URL(string: endpoint), isConfigured else { return nil }
        let config = ProviderConfig(
            id: "gui",
            kind: ProviderKind(rawValue: providerKind) ?? .s3compat,
            endpoint: ep,
            region: region.isEmpty ? "auto" : region,
            bucket: bucket,
            pathStyle: pathStyle,
            publicBase: publicBase.isEmpty ? nil : URL(string: publicBase)
        )
        return S3CompatProvider(
            config: config,
            credentials: SigV4Credentials(accessKeyID: accessKey, secretAccessKey: secretKey)
        )
    }

    var namingScheme: NamingScheme {
        NamingScheme(slugLength: Int(slugLength), datePrefix: datePrefix)
    }

    /// Fill in the local MinIO dev target (see `~/.nab-minio`).
    /// Dev-only credentials — never reuse for a real bucket.
    func loadLocalDevConfig() {
        providerKind = "minio"
        endpoint = "http://localhost:9000"
        bucket = "shots"
        region = "us-east-1"
        accessKey = "nab"
        secretKey = "nab12345" // MinIO requires the secret to be >= 8 chars
        publicBase = ""
        pathStyle = true
    }
}
