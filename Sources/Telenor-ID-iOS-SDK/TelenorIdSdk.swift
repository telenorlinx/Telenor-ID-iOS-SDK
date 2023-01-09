import Foundation

public enum TelenorIdSdk {
    // Version of the SDK must match the one published on github. This value is stored here
    // so that SDK users can get the current SDK version in runtime for, for example, analytics purposes.
    static var version = "1.0.0"

    private static var configuration: Configuration?

    public static func useConfiguration(_ configuration: Configuration) {
        self.configuration = configuration
    }

    public static func networkService() -> NetworkService {
        guard let configuration = TelenorIdSdk.configuration else {
            fatalError("""
                You must provide configuration before accessing NetworkService.
                Call `TelenorIdSdk.useConfiguration()` before accessing shared instance.
            """)
        }
        return NetworkService.useConfiguration(configuration)
    }

    public static func getSelfServiceLink(
        uiLocales: Set<String> = [Locale.preferredLanguages[0]],
        loginHints: Set<String>? = nil
    ) -> URLComponents {
        guard let configuration = TelenorIdSdk.configuration else {
            fatalError("""
                You must provide configuration before accessing NetworkService.
                Call `TelenorIdSdk.useConfiguration()` before accessing shared instance.
            """)
        }
        var urlComponents = Endpoint.selfService(configuration)
        urlComponents.queryItems = [
            URLQueryItem(name: Parameter.uiLocales(), value: uiLocales.joined(separator: " "))
        ]

        if let loginHints = loginHints, !loginHints.isEmpty {
            for loginHint in loginHints {
                urlComponents.queryItems?.append(URLQueryItem(name: Parameter.loginHint(), value: loginHint))
            }
        }

        return urlComponents
    }
}
