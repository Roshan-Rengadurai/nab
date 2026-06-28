import Foundation
import CryptoKit

/// Marker used by the package smoke test in Task 1.
public enum SnipCore {
    public static let packageIsWired = true
}

/// Lowercase hex encoding of raw bytes.
public func hexLower(_ data: Data) -> String {
    let table = Array("0123456789abcdef".utf8)
    var out = [UInt8]()
    out.reserveCapacity(data.count * 2)
    for byte in data {
        out.append(table[Int(byte >> 4)])
        out.append(table[Int(byte & 0x0f)])
    }
    return String(decoding: out, as: UTF8.self)
}

public func sha256Hex(_ data: Data) -> String {
    hexLower(Data(SHA256.hash(data: data)))
}

public func sha256Hex(_ string: String) -> String {
    sha256Hex(Data(string.utf8))
}

public func hmacSHA256(key: Data, _ data: Data) -> Data {
    let mac = HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key))
    return Data(mac)
}

public func hmacSHA256(key: Data, _ string: String) -> Data {
    hmacSHA256(key: key, Data(string.utf8))
}
