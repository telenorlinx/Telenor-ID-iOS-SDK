import Foundation

public enum StorageItem: String, CaseIterable {
    case accessToken, refreshToken, tokenType, scope, idToken, expiresIn

    func getAccountName() -> String {
        switch self {
        case .accessToken:
            return "TelenorIdAccessToken"
        case .refreshToken:
            return "TelenorIdRefreshToken"
        case .tokenType:
            return "TelenorIdTokenType"
        case .scope:
            return "TelenorIdScope"
        case .idToken:
            return "TelenorIdIdToken"
        case .expiresIn:
            return "TelenorIdExpiresIn"
        }
    }

    func getLegacyAccountName() -> String {
        switch self {
        case .accessToken:
            return "AccessToken"
        case .refreshToken:
            return "RefreshToken"
        case .idToken:
            return "IdToken"
        default:
            return getAccountName()
        }
    }
}
