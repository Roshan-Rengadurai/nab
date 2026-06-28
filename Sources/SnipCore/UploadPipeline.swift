import Foundation

public final class UploadPipeline {
    private let provider: StorageProvider
    private let uploader: ObjectUploader
    private let clipboard: ClipboardWriting
    private let keyGenerator: KeyGenerator
    private let optimisticThresholdBytes: Int
    private let presignTTL: Int

    public init(
        provider: StorageProvider,
        uploader: ObjectUploader,
        clipboard: ClipboardWriting,
        namingScheme: NamingScheme,
        optimisticThresholdBytes: Int = 5 * 1024 * 1024,
        presignTTL: Int = 300
    ) {
        self.provider = provider
        self.uploader = uploader
        self.clipboard = clipboard
        self.keyGenerator = KeyGenerator(scheme: namingScheme)
        self.optimisticThresholdBytes = optimisticThresholdBytes
        self.presignTTL = presignTTL
    }

    public func upload(
        _ item: UploadItem,
        date: Date = Date(),
        using rng: inout some RandomNumberGenerator
    ) async throws -> UploadOutcome {
        let key = keyGenerator.makeKey(ext: item.fileExtension, date: date, using: &rng)
        let publicURL = provider.publicURL(forKey: key)

        // Optimistic-clipboard correctness guard (spec §6): pre-copy only for
        // normal, sub-threshold, non-burner uploads.
        let preCopy = !item.isBurner && item.data.count <= optimisticThresholdBytes
        if preCopy {
            clipboard.writeURL(publicURL)
        }

        let putURL = try provider.presignPutURL(key: key, expiresIn: presignTTL, date: date)
        let contentType = ContentType.mime(forExtension: item.fileExtension)
        try await uploader.put(data: item.data, to: putURL, contentType: contentType)

        if !preCopy {
            clipboard.writeURL(publicURL)
        }

        return UploadOutcome(key: key, url: publicURL, copiedOptimistically: preCopy, verified: true)
    }
}
