import Foundation
import JWTKit

// You should sign your JWT with a backend service in a production use-case
func generateSignature(sessionName: String, role: Int, sdkKey: String, sdkSecret: String) async throws -> String {
    let iat = Int(Date().timeIntervalSince1970) - 30
    let exp = iat + 60 * 60 * 2

    let payload = JWTExample(
        app_key: sdkKey,
        tpc: sessionName,
        role_type: role,
        version: 1,
        iat: .init(value: Date(timeIntervalSince1970: TimeInterval(iat))),
        exp: .init(value: Date(timeIntervalSince1970: TimeInterval(exp)))
    )

    let keys = JWTKeyCollection()
    await keys.add(hmac: HMACKey(from: sdkSecret), digestAlgorithm: .sha256)
    let jwt = try await keys.sign(payload)
    print("JWT: \(jwt)")
    return jwt
}

// MARK: - JWT Payload

private struct JWTExample: JWTPayload {
    let app_key: String
    let tpc: String
    let role_type: Int
    let version: Int
    let iat: IssuedAtClaim
    let exp: ExpirationClaim

    func verify(using _: some JWTKit.JWTAlgorithm) async throws {
        try exp.verifyNotExpired()
    }
}
