import Foundation

public struct Configuration {
    public var redirectUrl: String
    public var clientId: String
    public var environment: Environment
    public var callbackUrlScheme: String

    public init(
        environment: Environment = Environment.test,
        clientId: String,
        redirectUrl: String,
        callbackUrlScheme: String
    ) {
        self.clientId = clientId
        self.redirectUrl = redirectUrl
        self.environment = .staging
        self.callbackUrlScheme = callbackUrlScheme
    }
}
