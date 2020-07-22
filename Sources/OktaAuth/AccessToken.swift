import Foundation

public struct OktaCredentials: Codable {
    let accessToken: String
    let tokenType: String
    let scope: String
    let idToken: String
    let expiresIn: TimeInterval
}
