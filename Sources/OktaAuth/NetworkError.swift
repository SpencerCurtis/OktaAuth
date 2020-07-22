import Foundation

public enum NetworkError: Error {
    case badURL
    case serverError(Error)
    case noData
    case noDecode
    case badResponse
    case noToken
}
