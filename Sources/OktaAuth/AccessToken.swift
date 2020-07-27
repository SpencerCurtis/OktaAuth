import Foundation

public struct OktaCredentials: Codable {
    public let accessToken: String
    public let tokenType: String
    public let scope: String
    public let idToken: String
    public let expiresIn: TimeInterval
    public var userID: String? = nil
}
