import Foundation

enum Endpoint: String {
    case authorization = "/oauth/authorize",
        token = "/oauth/token",
        tokeninfo = "/oauth/tokeninfo",
        userinfo = "/oauth/userinfo",
        revoke = "/oauth/revoke",
        logout = "/oauth/logout",
        wellKnown = "/oauth/.well-known/openid-configuration",
        issuer = "/oauth",
        selfService = "/overview"

    func callAsFunction(_ configuration: Configuration) -> URLComponents {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = self == .selfService
        ? Host.getSelfServiceHost(environment: configuration.environment)
        : Host.getIdHost(environment: configuration.environment)
        urlComponents.path = self.rawValue
        return urlComponents
    }
}
