//
//  JitsiJWTTokenBuilder.swift
//  AllGram
//
//  Created by Vladyslav on 20.12.2021.
//

import Foundation
import SwiftJWT
import MatrixSDK

class JitsiJWTTokenBuilder {
    static func build(jitsiServerDomain: String,
                      openIdToken: MXOpenIdToken,
                      roomId: String,
                      userAvatarUrl: String,
                      userDisplayName: String) throws -> String {
               
               // Create Jitsi JWT
               let jitsiJWTPayloadContextMatrix = JitsiJWTPayloadContextMatrix(token: openIdToken.accessToken,
                                                                               roomId: roomId,
                                                                               serverName: openIdToken.matrixServerName)
               let jitsiJWTPayloadContextUser = JitsiJWTPayloadContextUser(avatar: userAvatarUrl, name: userDisplayName)
               let jitsiJWTPayloadContext = JitsiJWTPayloadContext(matrix: jitsiJWTPayloadContextMatrix, user: jitsiJWTPayloadContextUser)
               
               let jitsiJWTPayload = JitsiJWTPayload(iss: jitsiServerDomain,
                                             sub: jitsiServerDomain,
                                             aud: "https://\(jitsiServerDomain)",
                   room: "*",
                   context: jitsiJWTPayloadContext)
               
               let jitsiJWT = JWT(claims: jitsiJWTPayload)
                               
               // Sign JWT
               // The secret string here is irrelevant, we're only using the JWT
               // to transport data to Prosody in the Jitsi stack.
               let privateKeyData = generatePivateKeyData()
               let jwtSigner = JWTSigner.hs256(key: privateKeyData)
               
               // Encode JWT token
               let jwtEncoder = JWTEncoder(jwtSigner: jwtSigner)
               let jwtString = try jwtEncoder.encodeToString(jitsiJWT)
               
               return jwtString
           }
}

fileprivate func generatePivateKeyData() -> Data {
    return "unused string".data(using: .utf8, allowLossyConversion: true)!
}
