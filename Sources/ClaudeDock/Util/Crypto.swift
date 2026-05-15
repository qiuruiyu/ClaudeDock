import Foundation
import CryptoKit

enum Crypto {
    static func sha1Hex(_ s: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    static func sha1Prefix(_ s: String, length: Int) -> String {
        String(sha1Hex(s).prefix(length))
    }
}
