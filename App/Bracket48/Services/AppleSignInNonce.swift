import CryptoKit
import Foundation
import Security

enum AppleSignInNonce {
    private static let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    static func random(length: Int = 32) throws -> String {
        precondition(length > 0)

        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomByte: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &randomByte)

            guard status == errSecSuccess else {
                throw BackendServiceError.transportFailed("Unable to generate a secure Apple sign-in nonce.")
            }

            if randomByte < UInt8(charset.count) {
                result.append(charset[Int(randomByte)])
                remainingLength -= 1
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)

        return hashedData.map { byte in
            String(format: "%02x", byte)
        }.joined()
    }
}
