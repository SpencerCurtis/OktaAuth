//
//  AuthenticationHelper.swift
//  LabsScaffolding
//
//  Created by Spencer Curtis on 6/25/20.
//  Copyright © 2020 Spencer Curtis. All rights reserved.
//

import Foundation
import CommonCrypto

extension Notification.Name {
    static let receivedCode = Notification.Name("receivedCode")
}

final public class OktaAuth {
    
    /// This should be the URL to your Okta authentication server. Ensure this has the "/authorize" endpoint as well. For example: https://yourAuthServer.okta.com
    private var baseURL: URL
    
    /// This adds the correct endpoints to the `baseURL` for the authorization of a user
    public var authURL: URL {
        return baseURL
            .appendingPathComponent("oauth2/default/v1/authorize")
    }
    
    /// This adds the correct endpoints to the `baseURL` for getting the access token for requests that require authentication
    public var accessTokenURL: URL {
        return baseURL
            .appendingPathComponent("/oauth2/default/v1/token")
    }
    
    /// Matches the Client ID of your Okta OAuth application that you created. You can find it at the bottom of your application's General tab in Okta.
    /// Should look something like this: `0oacfa90iqbWwsV0R4x6`
    private var clientID: String
    
    /// This is the URL with a custom scheme that you set up when you created your Okta application. You can view your redirect URI(s) and add more in the application's General Settings under __Login redirect URIs__. See [this screenshot](https://tk-assets.lambdaschool.com/276caf96-fcd4-4ccc-80af-bb3ec46f9f0f_ScreenShot2020-07-16at4.38.27PM.png).
    private var redirectURI: String
    
    /// State is used to verify that the server we send the request to is the same one that gives us a response back.
    private var currentState: String = ""
    
    private var currentCodeChallenge: String = ""
    private var code: String = ""
    
    private var hasBeenSetUp = false
    
    private var credentialExpiry: Date?
    private var oktaCredentials: OktaCredentials?
    
    private let verifier: String = {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        
        return Data(buffer)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }()
    
    public init(baseURL: URL,
         clientID: String,
         redirectURI: String) {
        
        self.baseURL = baseURL
        self.clientID = clientID
        self.redirectURI = redirectURI
    }
    
    // MARK: - Authentication
    
    /**
     This method returns a URL that you should pass into `UIApplication.shared.open` in order to open the user's browser to have them sign in.
     */
    
    public func identityAuthURL() -> URL? {
                
        guard let codeChallenge = createCodeChallenge() else { return nil }
        self.currentCodeChallenge = codeChallenge
        
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: true)
        currentState = UUID().uuidString
        components?.queryItems = [URLQueryItem(name: OAuthKeys.clientID.rawValue, value: clientID),
                                  URLQueryItem(name: OAuthKeys.responseType.rawValue, value: "code"),
                                  URLQueryItem(name: OAuthKeys.scope.rawValue, value: "openid"),
                                  URLQueryItem(name: OAuthKeys.redirectURI.rawValue, value: redirectURI),
                                  URLQueryItem(name: OAuthKeys.state.rawValue, value: currentState),
                                  URLQueryItem(name: OAuthKeys.codeChallengeMethod.rawValue, value: "S256"),
                                  URLQueryItem(name: OAuthKeys.codeChallenge.rawValue, value: codeChallenge)]
        
        return components?.url
    }
    
    /**
     
     This method should be called in the SceneDelegate's `scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>)` method. Assuming the authentication succeeds, you can then access the returned `OktaCredentials` in this class' `oktaCredentials` property. These credentials contain the access token that will allow you to access protected endpoints in your web backend.
        
     - parameters:
     - url: The URL returned to you from one the SceneDelegate's [UIOpenURLContext](https://developer.apple.com/documentation/uikit/uiopenurlcontext?language=objc).
     
     - completion: returns a Result with `Void` as its success type and `NetworkError` as its failure type. As the method sets the credentials in a property in this class for easier access in your app, the success type `Void` can be ignored. You should still however handle errors appropriately.
     */
    
    public func receiveCredentials(fromCallbackURL url: URL, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        let components = URLComponents(string: url.absoluteString)
        
        guard let code = components?.queryItems?.filter({ $0.name == OAuthKeys.code.rawValue }).first?.value,
            let state = components?.queryItems?.filter({ $0.name == OAuthKeys.state.rawValue }).first?.value else {
                NSLog("Code and/or state were not returned from Okta")
                return
        }
        
        guard state == currentState else {
            NSLog("States do not match")
            return
        }
        
        let pairs = [(OAuthKeys.grantType.rawValue, "authorization_code"),
                     (OAuthKeys.clientID.rawValue, clientID),
                     (OAuthKeys.redirectURI.rawValue, redirectURI),
                     (OAuthKeys.code.rawValue, code),
                     (OAuthKeys.codeVerifier.rawValue, verifier)]
        
        var dataString = ""
        
        for pair in pairs {
            dataString += "\(pair.0)=\(pair.1)"
            if pairs.last! != pair {
                dataString += "&"
            }
        }
        
        
        guard let httpBody = dataString.data(using: .utf8) else {
            completion(.failure(.badResponse))
            NSLog("Error encoding access token dictionary")
            return
        }
        
        
        var request = URLRequest(url: accessTokenURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: HeaderField.accept.rawValue)
        request.addValue("no-cache", forHTTPHeaderField: "cache-control")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: HeaderField.contentType.rawValue)
        request.httpBody = httpBody
        
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                NSLog("Error getting access token: \(error)")
                completion(.failure(.serverError(error)))
                return
            }
            
            guard let data = data else {
                NSLog("No data returned from access token request")
                completion(.failure(.noData))
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                var credentials = try decoder.decode(OktaCredentials.self, from: data)
                credentials.userID = try self.decode(jwtToken: credentials.accessToken)["uid"] as? String
                self.oktaCredentials = credentials
                
                completion(.success(Void()))
            } catch {
                NSLog("Error decoding access token: \(error)")
                completion(.failure(.noDecode))
            }
        }.resume()
    }
    
    func credentialsIfAvailable() throws -> OktaCredentials {
        guard let oktaCredentials = oktaCredentials else {
            throw CredentialError.noCredentials
        }
        
        if let credentialExpiry = credentialExpiry,
            Date() > credentialExpiry {
            throw CredentialError.expiredCredentials
        }
        
        return oktaCredentials
    }
    
    enum CredentialError: Error {
        case noCredentials
        case expiredCredentials
    }
    
    
    // MARK: - Private Methods
    
    
    private func createCodeChallenge() -> String? {
        guard let data = verifier.data(using: .utf8) else { return nil }
        var buffer = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        
        data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            _ = CC_SHA256(pointer.baseAddress, CC_LONG(data.count), &buffer)
        }
        
        let hash = Data(buffer)
        
        return hash.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    func decode(jwtToken jwt: String) throws -> [String: Any] {
        
        enum DecodeErrors: Error {
            case badToken
            case other
        }
        
        func base64Decode(_ base64: String) throws -> Data {
            let padded = base64.padding(toLength: ((base64.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
            guard let decoded = Data(base64Encoded: padded) else {
                throw DecodeErrors.badToken
            }
            return decoded
        }
        
        func decodeJWTPart(_ value: String) throws -> [String: Any] {
            let bodyData = try base64Decode(value)
            let json = try JSONSerialization.jsonObject(with: bodyData, options: [])
            guard let payload = json as? [String: Any] else {
                throw DecodeErrors.other
            }
            return payload
        }
        
        let segments = jwt.components(separatedBy: ".")
        return try decodeJWTPart(segments[1])
    }
    
    // MARK: - Private enums
    
    private enum OAuthKeys: String {
        case clientID = "client_id"
        case clientSecret = "client_secret"
        case responseType = "response_type"
        case redirectURI = "redirect_uri"
        case codeChallengeMethod = "code_challenge_method"
        case codeChallenge = "code_challenge"
        case grantType = "grant_type"
        case codeVerifier = "code_verifier"
        case code
        case state
        case scope
    }
    
    private enum HTTPMethod: String {
        case get = "GET"
        case put = "PUT"
        case post = "POST"
        case delete = "DELETE"
    }
    
    private enum HeaderField: String {
        case accept = "Accept"
        case contentType = "Content-Type"
        case authorization = "Authorization"
        case cacheControl = "cache-control"
    }
    
    private enum PersistenceKeys: String {
        case baseURL
        case clientID
        case redirectURI
        case oktaAuth
    }
}
