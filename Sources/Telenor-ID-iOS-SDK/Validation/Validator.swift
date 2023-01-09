import Foundation

public enum Validator {
    public static func isAccessTokenValid(validTimaGap: Int) -> Bool {
        let expirationTime: String
        do {
            expirationTime = try StorageService.get(item: StorageItem.expiresIn)
        } catch {
            return false
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YY, MMM d, HH:mm:ss"

        guard let expirationDate = dateFormatter.date(from: expirationTime),
            let currentDate = Calendar.current.date(byAdding: .second, value: validTimaGap, to: Date()) else {
            return false
        }

        return expirationDate.timeIntervalSince(currentDate) > 0
    }

    static func validateIdToken(
        token: [String: Any],
        expectedIssuer: String,
        expectedAudience: String,
        serverTime: Date?
    ) throws {
        guard let issuer = token["iss"] as? String else {
            throw IdTokenValidationError.missingIssuer
        }

        if issuer != expectedIssuer {
            throw IdTokenValidationError.incorrectIssuer("""
                Found issuer was: \(issuer) while expected issuer is: \(expectedIssuer)
            """)
        }

        guard let audience = token["aud"] as? [String] else {
            throw IdTokenValidationError.missingAudience("ID token audience was nil.")
        }

        if !audience.contains(expectedAudience) {
            throw IdTokenValidationError.missingAudience("""
                ID token audience list does not contain the configured client ID.
            """)
        }

        let untrustedAudiences = audience.filter { (str: String) -> Bool in
            str != expectedAudience
        }
        if !untrustedAudiences.isEmpty {
            throw IdTokenValidationError.untrustedAudiences("ID token audience list contains untrusted audiences.")
        }

        let authorizedParty: String? = token["azp"] as? String
        if audience.count > 1 && authorizedParty == nil {
            throw IdTokenValidationError.authorizedPartyMissing("""
                ID token contains multiple audiences but no azp claim is present.
            """)
        }

        if audience.count > 1 && authorizedParty != expectedAudience {
            throw IdTokenValidationError.authorizedPartyMismatch("""
                ID token authorized party is not the configured client ID.
            """)
        }

        let doubleExperationTime = token["exp"] as? Double
        guard let experationTime = token["exp"] as? TimeInterval ?? doubleExperationTime as TimeInterval? else {
            throw IdTokenValidationError.experationTimeMissing
        }

        let expirationDate = Date(timeIntervalSince1970: experationTime)
        if !isValidExpirationTime(expirationDate: expirationDate, serverDate: serverTime) {
            throw IdTokenValidationError.expired("ID token has expired.")
        }

        guard token["iat"] != nil else {
            throw IdTokenValidationError.missingIssueTime("ID token is missing the \"iat\" claim.")
        }
    }

    private static func isValidExpirationTime(expirationDate: Date, serverDate: Date?) -> Bool {
        if expirationDate.timeIntervalSinceNow.sign == FloatingPointSign.plus {
            return true
        }

        guard let serverDate = serverDate else {
            return false
        }

        let expired = expirationDate > serverDate
        return expired
    }
}
