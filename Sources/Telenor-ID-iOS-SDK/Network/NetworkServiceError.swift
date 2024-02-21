import Foundation

public enum NetworkServiceError: Error {
    case invalidCode,
        essentialClaimsParsingException,
        unsuccessfulResponse(message: String?),
        idTokenMissingAtLogout
}
