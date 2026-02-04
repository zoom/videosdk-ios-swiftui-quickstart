import Foundation
import JWTKit

// MARK: - Entry

guard CommandLine.arguments.count >= 4 else {
    print("Usage:")
    print("swift run signer SDKKEY SDKSECRET SESSION_NAME [ROLE]")
    exit(1)
}

let sdkKey = CommandLine.arguments[1]
let sdkSecret = CommandLine.arguments[2]
let sessionName = CommandLine.arguments[3]
let role = CommandLine.arguments.count >= 5 ? Int(CommandLine.arguments[4]) ?? 1 : 1

do {
    let jwt = try generateSignature(
        sessionName: sessionName,
        role: role,
        sdkKey: sdkKey,
        sdkSecret: sdkSecret
    )

    print(jwt)
} catch {
    print("Error generating JWT:", error)
    exit(1)
}

// MARK: - JWT Generator

func generateSignature(
    sessionName: String,
    role: Int,
    sdkKey: String,
    sdkSecret: String
) throws -> String {

    let iat = Int(Date().timeIntervalSince1970) - 30
    let exp = iat + 60 * 60 * 2 // 2 hours

    let payload = JWTExample(
        app_key: sdkKey,
        tpc: sessionName,
        role_type: role,
        version: 1,
        iat: IssuedAtClaim(value: Date(timeIntervalSince1970: TimeInterval(iat))),
        exp: ExpirationClaim(value: Date(timeIntervalSince1970: TimeInterval(exp)))
    )

    var signers = JWTSigners()
    signers.use(.hs256(key: sdkSecret))

    return try signers.sign(payload)
}

// MARK: - JWT Payload

struct JWTExample: JWTPayload {
    let app_key: String
    let tpc: String
    let role_type: Int
    let version: Int
    let iat: IssuedAtClaim
    let exp: ExpirationClaim

    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}
