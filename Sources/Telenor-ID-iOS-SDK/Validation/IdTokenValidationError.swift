import Foundation

public enum IdTokenValidationError: Error {
    case incorrectIssuer(String),
        missingIssuer,
        missingAudience(String),
        untrustedAudiences(String),
        authorizedPartyMissing(String),
        authorizedPartyMismatch(String),
        experationTimeMissing,
        expired(String),
        missingIssueTime(String)
}
