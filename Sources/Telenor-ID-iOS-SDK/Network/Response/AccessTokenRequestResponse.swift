import Foundation

// The names here has to be equal to the names that come in network response to make
// mapping work. For that reason the style check for name variables is disabled.
// swiftlint:disable identifier_name
public struct AccessTokenRequestResponse: Codable {
    let access_token: String
    let refresh_token: String
    let id_token: String
    let scope: String
    let token_type: String
    let expires_in: Int
}
