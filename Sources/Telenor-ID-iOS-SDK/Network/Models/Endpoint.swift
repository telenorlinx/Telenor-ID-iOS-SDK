import Foundation

enum Endpoint: String {
    case authorization = "/connect/authorize",
        token = "/connect/token",
        userinfo = "/connect/userinfo",
        revoke = "/oauth/revoke", // TODO(serhii): not there yet?
        logout = "/v1/logout",
        wellKnown = "/.well-known/openid-configuration",
        issuer = ""

    func callAsFunction(_ configuration: Configuration) -> URLComponents {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = Host.getIdHost(environment: configuration.environment)
        urlComponents.path = self.rawValue
        return urlComponents
    }
}
