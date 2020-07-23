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
    static var receivedCode = Notification.Name("receivedCode")
}

final public class OktaAuth {
    
    public static let shared = OktaAuth()
    
    private var _baseURL: URL?
    
    /// This should be the URL to your Okta authentication server. Ensure this has the "/authorize" endpoint as well. For example: https://yourAuthServer.okta.com
    private var baseURL: URL {
        get {
            guard let baseURL = _baseURL else {
                fatalError("Base URL is nil. Please call the `setUpConfiguration` method to provide the URL to your Okta authentication server")
            }
            return baseURL
        }
        
        set {
            _baseURL = newValue
        }
    }
    
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
    private var clientID = ""
    
    /// This is the URL with a custom scheme that you set up when you created your Okta application. You can view your redirect URI(s) and add more in the application's General Settings under __Login redirect URIs__. See [this screenshot](https://tk-assets.lambdaschool.com/276caf96-fcd4-4ccc-80af-bb3ec46f9f0f_ScreenShot2020-07-16at4.38.27PM.png).
    private var redirectURI = ""
    
    /// State is used to verify that the server we send the request to is the same one that gives us a response back.
    private var currentState: String = ""
    
    private var currentCodeChallenge: String = ""
    private var code: String = ""
    
    private var hasBeenSetUp = false
    
    public var oktaCredentials: OktaCredentials?
    
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
    
    
    private init() {
        loadPreviousConfiguration()
    }
    /// This method must be called first before using any other method in this class. Without calling this, your app will crash due to OktaAuth not having the necessary information to give you an access token.
    public func setUpConfiguration(baseURL: URL,
                                   clientID: String,
                                   redirectURI: String) {
        self.baseURL = baseURL
        self.clientID = clientID
        self.redirectURI = redirectURI
        
        saveCurrentConfiguration()
        self.hasBeenSetUp = true
    }
    
    
    
    
    // MARK: - Authentication
    
    /**
     
     This method returns a URL that you should pass into `UIApplication.shared.open` in order to open the user's browser to have them sign in.
     
     - precondition: You must have called `setUpConfiguration` before calling this method.
     
     */
    public func identityAuthURL() -> URL? {
        
        verifySetUp()
        
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
     
     - precondition: You must have called `setUpConfiguration` before calling this method.
     
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
                let credentials = try decoder.decode(OktaCredentials.self, from: data)
                self.oktaCredentials = credentials
                completion(.success(Void()))
            } catch {
                NSLog("Error decoding access token: \(error)")
                completion(.failure(.noDecode))
            }
        }.resume()
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
    
    // MARK: Configuration Persistence
    
    /// Saving the current configuration is necessary as the app may close in the background as the user is authenticating through Okta in a browser. This way, the configuration can be loaded up again and the authentication process can resume normally.
    
    private func saveCurrentConfiguration() {
        let configDictionary: [String: Any] = [PersistenceKeys.baseURL.rawValue: baseURL.absoluteString,
                                               PersistenceKeys.clientID.rawValue: clientID,
                                               PersistenceKeys.redirectURI.rawValue: redirectURI]
        
        UserDefaults.standard.set(configDictionary, forKey: PersistenceKeys.oktaAuth.rawValue)
    }
    
    private func loadPreviousConfiguration() {
        guard let configDictionary = UserDefaults.standard.dictionary(forKey: PersistenceKeys.oktaAuth.rawValue) else { return }
        
        if let baseURLString = configDictionary[PersistenceKeys.baseURL.rawValue] as? String,
            let baseURL = URL(string: baseURLString),
            let clientID = configDictionary[PersistenceKeys.clientID.rawValue] as? String,
            let redirectURI = configDictionary[PersistenceKeys.redirectURI.rawValue] as? String {
            
            self.baseURL = baseURL
            self.clientID = clientID
            self.redirectURI = redirectURI
            hasBeenSetUp = true
        }
    }
    
    private func verifySetUp() {
        guard hasBeenSetUp else {
            fatalError("ERROR: Please call the `setUpConfiguration` method to supply the necessary information for your Okta authentication server before using anything else in this class.")
        }
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
