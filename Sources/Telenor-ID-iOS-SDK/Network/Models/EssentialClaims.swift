import Foundation

public enum EssentialClaims: String, Encodable {
    case name = "name",
        locale = "locale",
        email = "email",
        emailVerified = "email_verified",
        phoneNumber = "phone_number",
        phoneNumberVerified = "phone_number_verified"
}
