import Foundation

public struct NamingScheme: Equatable {
    public var slugLength: Int
    public var datePrefix: Bool
    public init(slugLength: Int = 10, datePrefix: Bool = false) {
        self.slugLength = slugLength
        self.datePrefix = datePrefix
    }
}

public struct KeyGenerator {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    public let scheme: NamingScheme

    public init(scheme: NamingScheme) {
        self.scheme = scheme
    }

    public func makeKey(ext: String, date: Date = Date(), using rng: inout some RandomNumberGenerator) -> String {
        var slug = ""
        slug.reserveCapacity(scheme.slugLength)
        for _ in 0..<scheme.slugLength {
            let idx = Int.random(in: 0..<Self.alphabet.count, using: &rng)
            slug.append(Self.alphabet[idx])
        }
        let cleanExt = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let suffix = cleanExt.isEmpty ? "" : ".\(cleanExt)"
        if scheme.datePrefix {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = "yyyy-MM-dd"
            return "\(f.string(from: date))-\(slug)\(suffix)"
        }
        return "\(slug)\(suffix)"
    }
}
