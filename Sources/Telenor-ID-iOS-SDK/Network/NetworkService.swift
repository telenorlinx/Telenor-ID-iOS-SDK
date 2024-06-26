import Foundation
import CryptoKit
import Alamofire
import UIKit

// swiftlint:disable type_body_length
// swiftlint:disable function_body_length
// swiftlint:disable file_length
public class NetworkService {
    private static var configuration: Configuration?

    private let timeout: Double = 60.0 // seconds

    // SDK does not support other response types
    private let responseType: String = "code"

    // SDK requires specific values passed as grant types to relevant requests
    private let getAccessTokenGrantType: String = "authorization_code"
    private let refreshAccessTokenGrantType: String = "refresh_token"
    
    // SDK requires specific challenge method for code_challenge
    private let codeChallengeMethod: String = "S256"

    // Network requests initiated by SDK must not run on UI thread
    private let queue = DispatchQueue(
        label: "Telenor ID SDK Network service queue",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let semaphore = DispatchSemaphore(value: 1)

    // SDK services should be singletones
    private static let shared = NetworkService()

    private init() {
        guard NetworkService.configuration != nil else {
            fatalError("""
                You must provide configuration before accessing NetworkService.
                Use `.useConfiguration()` before accessing shared instance.
            """)
        }
    }

    class func useConfiguration(_ configuration: Configuration) -> NetworkService {
        self.configuration = configuration
        return shared
    }

    // Call to authenticate
    public func authorize(
        scope: Set<String>,
        state: String? = nil,
        prompt: Prompt? = nil,
        acrValues: Set<String>? = nil,
        maxAge: Int? = nil,
        loginHints: Set<String>? = nil,
        logSessionId: UUID? = nil,
        essentialClaims: Set<EssentialClaims>? = nil,
        uiLocales: Set<String> = [Locale.preferredLanguages[0]],
        viewControllerContext: Any?,
        onComplete: @escaping (OperationStatus, String?, Int?, Error?) -> Void
    ) {
        guard let configuration = NetworkService.configuration else {
            fatalError("""
                You must provide configuration before accessing NetworkService.
                Use `.useConfiguration()` before accessing shared instance.
            """)
        }
        
        let codeVerifier = createRandomString()
        guard let codeVerifierData = codeVerifier.data(using: .ascii) else {
            // This should never happen
            fatalError("""
                SDK was not able to generate code challenge for authentication request.
            """)
        }

        var urlComponents = Endpoint.authorization(configuration)
        urlComponents.queryItems = [
            URLQueryItem(name: Parameter.codeChallenge(), value: SHA256.hash(data: codeVerifierData).data.base64urlEncodedString()),
            URLQueryItem(name: Parameter.codeChallengeMethod(), value: codeChallengeMethod),
            URLQueryItem(name: Parameter.responseType(), value: responseType),
            URLQueryItem(name: Parameter.clientId(), value: configuration.clientId),
            URLQueryItem(name: Parameter.redirectUri(), value: configuration.redirectUrl),
            URLQueryItem(name: Parameter.scope(), value: scope.joined(separator: " ")),
            URLQueryItem(name: Parameter.uiLocales(), value: uiLocales.joined(separator: " ")),
            URLQueryItem(name: Parameter.telenordigitalSdkVersion(), value: getVersionString()),
            URLQueryItem(name: Parameter.logSessionId(), value: (logSessionId ?? UUID.init()).uuidString)
        ]

        // Supply a vendor id to track requests coming from the same vendor
        if let devideId = UIDevice.current.identifierForVendor?.uuidString {
            urlComponents.queryItems?.append(URLQueryItem(name: Parameter.telenordigitalDid(), value: devideId))
        }

        // State is required to validate the response, however it's not uncommon that client application doesn't hold
        // that information. In that case the random state will be generated and provided by SDK itself.
        let nonEmptyState = state ?? createRandomString()
        urlComponents.queryItems?.append(URLQueryItem(name: Parameter.state(), value: nonEmptyState))

        if let prompt = prompt {
            urlComponents.queryItems?.append(URLQueryItem(name: Parameter.prompt(), value: prompt.rawValue))
        }

        if let maxAge = maxAge {
            urlComponents.queryItems?.append(URLQueryItem(name: Parameter.maxAge(), value: String(maxAge)))
        }

        if let loginHints = loginHints, !loginHints.isEmpty {
            for loginHint in loginHints {
                urlComponents.queryItems?.append(URLQueryItem(name: Parameter.loginHint(), value: loginHint))
            }
        }

        if let acrValues = acrValues, !acrValues.isEmpty {
            urlComponents.queryItems?.append(
                URLQueryItem(name: Parameter.acrValues(), value: acrValues.map { String($0) }.joined(separator: " "))
            )
        }

        if !(essentialClaims ?? []).isEmpty {
            var essentialClaimsDictionary: [String: [String: [String: Bool]]] = [
                "userinfo": [:]
            ]

            essentialClaims?.forEach { claim in
                essentialClaimsDictionary["userinfo"]?[claim.rawValue] = [
                    "essential": true
                ]
            }

            let jsonData: Data
            do {
                jsonData = try JSONSerialization.data(withJSONObject: essentialClaimsDictionary)
            } catch {
                // This should never happen in a correct flow, therefor SDK should crash if error occures here
                fatalError("""
                    An error occured when parsing essential claims.
                    Error: \(error).
                    Description: \(error.localizedDescription)
                """)
            }
            let essentialClaimsJsonObjectString = String(data: jsonData, encoding: .utf8)

            urlComponents.queryItems?.append(
                URLQueryItem(name: Parameter.claims(), value: essentialClaimsJsonObjectString)
            )
        }

        // Apple does not consider "+" to be a special symbol
        urlComponents.percentEncodedQuery = urlComponents.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")

        guard let url = urlComponents.url else {
            fatalError("An error occured when generating the url.")
        }

        Browser(configuration).launch(
            scope: scope,
            codeVerifier: codeVerifier,
            url: url,
            viewControllerContext: viewControllerContext,
            state: nonEmptyState,
            onComplete: onComplete)
    }

    // This API is tightly connected to autorize method and should not be public
    func getAccessToken(
        scope: Set<String>,
        codeVerifier: String,
        code: String?,
        onComplete: @escaping (OperationStatus, String?, Int?, Error?) -> Void
    ) {
        queue.async {
            guard let code = code else {
                onComplete(OperationStatus.failure, nil, nil, NetworkServiceError.invalidCode)
                return
            }
            let (configuration, url) = self.getConfigurationAndUrl(endpoint: Endpoint.token)

            self.semaphore.wait()
            AF.request(
                url,
                method: .post,
                parameters: [
                    Parameter.codeVerifier(): codeVerifier,
                    Parameter.scope(): scope.joined(separator: " "),
                    Parameter.grantType(): self.getAccessTokenGrantType,
                    Parameter.code(): code,
                    Parameter.clientId(): configuration.clientId,
                    Parameter.redirectUri(): configuration.redirectUrl
                ]
            ) { $0.timeoutInterval = self.timeout }
                .validate(statusCode: [200])
                .responseDecodable(of: AccessTokenRequestResponse.self) { response in
                    let statusCode = response.response?.statusCode
                    switch response.result {
                    case .success(let accessTokenRequestResponse):
                        do {
                            let issuerUrlComponents = Endpoint.issuer(configuration)
                            guard let issuerUrlString = issuerUrlComponents.string else {
                                fatalError("""
                                    An error occured when generating the issuer url at getAccessToken() method.
                                """)
                            }
                            try Validator.validateIdToken(
                                token: IdToken.decode(accessTokenRequestResponse.id_token),
                                expectedIssuer: issuerUrlString,
                                expectedAudience: configuration.clientId,
                                serverTime: self.parseDateHeader(
                                    dateHeader: response.response?.allHeaderFields["Date"] as? String
                                )
                            )
                        } catch {
                            self.semaphore.signal()
                            onComplete(OperationStatus.failure, nil, statusCode, error)
                            return
                        }

                        guard let expirationTime = Calendar.current.date(
                            byAdding: .second,
                            value: accessTokenRequestResponse.expires_in,
                            to: Date()
                        ) else {
                            self.semaphore.signal()
                            onComplete(
                                OperationStatus.failure,
                                nil,
                                statusCode,
                                NetworkServiceError.unsuccessfulResponse(
                                    message: "SDK was unable to set the access token expiration date"
                                )
                            )
                            return
                        }

                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "YY, MMM d, HH:mm:ss"
                        let stringExpirationTime = dateFormatter.string(from: expirationTime)
                        do {
                            try StorageService.save(
                                item: StorageItem.accessToken,
                                value: accessTokenRequestResponse.access_token
                            )
                            try StorageService.save(
                                item: StorageItem.refreshToken,
                                value: accessTokenRequestResponse.refresh_token
                            )
                            try StorageService.save(
                                item: StorageItem.tokenType,
                                value: accessTokenRequestResponse.token_type
                            )
                            try StorageService.save(
                                item: StorageItem.scope,
                                value: accessTokenRequestResponse.scope
                            )
                            try StorageService.save(
                                item: StorageItem.idToken,
                                value: accessTokenRequestResponse.id_token
                            )
                            try StorageService.save(
                                item: StorageItem.expiresIn,
                                value: stringExpirationTime
                            )
                        } catch {
                            self.semaphore.signal()
                            onComplete(OperationStatus.failure, nil, statusCode, error)
                            return
                        }
                        self.semaphore.signal()
                        onComplete(OperationStatus.success, accessTokenRequestResponse.access_token, statusCode, nil)
                    case .failure(let AFerror):
                        if let data = response.data {
                            let stringResponse = String(data: data, encoding: String.Encoding.utf8)
                            self.semaphore.signal()
                            onComplete(
                                OperationStatus.failure,
                                nil,
                                statusCode,
                                NetworkServiceError.unsuccessfulResponse(message: stringResponse)
                            )
                            return
                        }
                        self.semaphore.signal()
                        onComplete(
                            OperationStatus.failure,
                            nil,
                            statusCode,
                            NetworkServiceError.unsuccessfulResponse(
                                message: """
                                    Request had failed but provided no extra information.
                                    Alamofire had reported next error: \(AFerror.localizedDescription)
                                """
                        ))
                    }
                }
        }
    }

    public func refreshAccessToken(onComplete: @escaping (OperationStatus, String?, Int?, Error?) -> Void, useTelenorIdEndpoint: Bool = false) {
        queue.async {
            let (configuration, url) = useTelenorIdEndpoint
            ? self.getLegacyConfigurationAndTokenRefreshUrl()
            : self.getConfigurationAndUrl(endpoint: Endpoint.token)

            self.semaphore.wait()

            let refreshToken: String
            do {
                refreshToken = try StorageService.get(item: StorageItem.refreshToken)
            } catch {
                self.semaphore.signal()
                onComplete(OperationStatus.failure, nil, nil, error)
                return
            }

            AF.request(
                url,
                method: .post,
                parameters: [
                    Parameter.grantType(): self.refreshAccessTokenGrantType,
                    Parameter.refreshToken(): refreshToken,
                    Parameter.clientId(): configuration.clientId
                ]
            ) { $0.timeoutInterval = self.timeout }
                .validate(statusCode: [200])
                .responseDecodable(of: RefreshTokenRequestResponse.self) { response in
                    let statusCode = response.response?.statusCode
                    switch response.result {
                    case .success(let refreshTokenRequestResponse):
                        guard let expirationTime = Calendar.current.date(
                            byAdding: .second,
                            value: refreshTokenRequestResponse.expires_in,
                            to: Date()
                        ) else {
                            self.semaphore.signal()
                            onComplete(
                                OperationStatus.failure,
                                nil,
                                statusCode,
                                NetworkServiceError.unsuccessfulResponse(
                                    message: """
                                        SDK was unable to set the access token expiration date
                                        after token refresh
                                    """
                                )
                            )
                            return
                        }

                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "YY, MMM d, HH:mm:ss"
                        let stringExpirationTime = dateFormatter.string(from: expirationTime)
                        do {
                            try StorageService.save(
                                item: StorageItem.accessToken,
                                value: refreshTokenRequestResponse.access_token
                            )
                            try StorageService.save(
                                item: StorageItem.refreshToken,
                                value: refreshTokenRequestResponse.refresh_token
                            )
                            try StorageService.save(
                                item: StorageItem.tokenType,
                                value: refreshTokenRequestResponse.token_type
                            )
                            try StorageService.save(
                                item: StorageItem.scope,
                                value: refreshTokenRequestResponse.scope
                            )
                            try StorageService.save(
                                item: StorageItem.expiresIn,
                                value: stringExpirationTime
                            )
                        } catch {
                            // In case of any saving had failed - the user will have to try to revoke the
                            // tokens and clean up the local storage
                            self.semaphore.signal()
                            onComplete(OperationStatus.failure, nil, statusCode, error)
                            return
                        }
                        self.semaphore.signal()
                        onComplete(OperationStatus.success, refreshTokenRequestResponse.access_token, statusCode, nil)
                    case .failure(let AFerror):
                        if let data = response.data {
                            let stringResponse = String(data: data, encoding: String.Encoding.utf8)
                            self.semaphore.signal()
                            onComplete(
                                OperationStatus.failure,
                                nil,
                                statusCode,
                                NetworkServiceError.unsuccessfulResponse(message: stringResponse)
                            )
                            return
                        }
                        self.semaphore.signal()
                        onComplete(OperationStatus.failure, nil, statusCode, NetworkServiceError.unsuccessfulResponse(
                            message: """
                                Request had failed but provided no extra information.
                                Alamofire had reported next error: \(AFerror.localizedDescription)
                            """
                        ))
                    }
                }
        }
    }

    public func logout(
        onComplete: @escaping (OperationStatus, String?, Int?, Error?) -> Void
    ) {
        queue.async {
            let (_, url) = self.getConfigurationAndUrl(endpoint: Endpoint.logout)

            self.semaphore.wait()

            var idToken: String?
            do {
                idToken = try StorageService.get(item: StorageItem.idToken)
            } catch {
                // Access token is missing and that's fine
                self.semaphore.signal()
                onComplete(OperationStatus.failure, nil, nil, NetworkServiceError.idTokenMissingAtLogout)
                return
            }

            guard let idToken = idToken else {
                // If access token is missing during logout attempt - try to refresh it
                self.semaphore.signal()
                self.refreshAccessToken { operationStatus, accessToken, _, error in
                    // In refresh was successfull we can make an attempt to
                    if operationStatus == .success && accessToken != nil {
                        // Try another one single logout, but without the retry if access token fetch fails
                        self.logout(onComplete: onComplete)
                    } else {
                        // If refresh token had failed for whatever reason - there is most likely nothing we can do
                        // In that case SDK should try to revoke tokens and clean them afterwards
                        self.revokeToken(tokenType: StorageItem.accessToken) { _, _, _, _ in }
                        self.revokeToken(tokenType: StorageItem.refreshToken) { _, _, _, _ in }
                        // SDK doesn't care about the outcome of the token revokation
                        // and will try to wipe tokens from the storage
                        do {
                            try StorageService.wipe()
                        } catch {
                            // If wipe had failed - present users with the error.
                            // In this case they will have to manually try to cleanup the tokens afterwards
                            onComplete(OperationStatus.failure, nil, nil, NetworkServiceError.unsuccessfulResponse(
                                message: "SDK had failed to wipe the tokens when finishing the logout request: \(error)"
                            ))
                        }
                        // When wipe is done - report back that everything went okay
                        onComplete(OperationStatus.success, nil, nil, nil)
                    }
                }
                return
            }

            // If token was present - we proceed to the logout
            AF.request(url, method: .post, parameters: [
                Parameter.idTokenHint(): idToken
            ]) {
                $0.timeoutInterval = self.timeout
            }
            .validate(statusCode: [200, 204])
            .response { response in
                self.semaphore.signal()
                let statusCode = response.response?.statusCode
                // If refresh token had failed for whatever reason - there is most likely nothing we can do
                // In that case SDK should try to revoke tokens and clean them afterwards
                self.revokeToken(tokenType: StorageItem.accessToken) { _, _, _, _ in }
                self.revokeToken(tokenType: StorageItem.refreshToken) { _, _, _, _ in }
                // SDK doesn't care about the outcome of the token revokation
                // and will try to wipe tokens from the storage
                do {
                    try StorageService.wipe()
                } catch {
                    // If wipe had failed - present users with the error. In this case they will have to manually try
                    // to cleanup the tokens afterwards
                    onComplete(OperationStatus.failure, nil, statusCode, NetworkServiceError.unsuccessfulResponse(
                        message: "SDK had failed to wipe the tokens when finishing the logout request: \(error)"
                    ))
                }
                // When wipe is done - report back that everything went okay
                onComplete(OperationStatus.success, nil, statusCode, nil)
            }
        }
    }

    // Revoking a token makes sure that the token can no longer be used.
    // The access token and refresh token known to the client should be deleted from client storage
    // and provided to this revoke endpoint when the tokens are no longer needed.
    //
    // TODO: Revoke token endpoint is not supported in ID+ for now.
    private func revokeToken(
        tokenType: StorageItem,
        onComplete: @escaping (OperationStatus, String?, Int?, Error?) -> Void
    ) {
        return;
        /*
        queue.async {
            let (configuration, url) = self.getConfigurationAndUrl(endpoint: Endpoint.revoke)

            self.semaphore.wait()
            var token: String
            do {
                token = try StorageService.get(item: tokenType)
            } catch {
                // Token cannot be revoked because it's missing
                self.semaphore.signal()
                onComplete(OperationStatus.failure, nil, nil, error)
                return
            }

            AF.request(
                url,
                method: .post,
                parameters: [
                    Parameter.token(): token,
                    Parameter.clientId(): configuration.clientId
                ]
            ) { $0.timeoutInterval = self.timeout }
                .validate(statusCode: [200])
                .response { response in
                    let statusCode = response.response?.statusCode
                    do {
                        // It doesn't matter to SDK if token was revoced or not. The item should be deleted locally.
                        try StorageService.delete(item: tokenType)
                    } catch {
                        // Delete failed, user has to ensure tokens are gone.
                        self.semaphore.signal()
                        onComplete(OperationStatus.failure, nil, statusCode, error)
                        return
                    }
                    // All good.
                    self.semaphore.signal()
                    onComplete(OperationStatus.success, nil, statusCode, nil)
                }
        }
         */
    }

    private func parseDateHeader(dateHeader: String?) -> Date? {
        guard let dateHeader = dateHeader else {
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"

        return dateFormatter.date(from: dateHeader)
    }

    private func getVersionString() -> String {
        let operatingSystem = ProcessInfo.processInfo.operatingSystemVersion
        var versionString = "ios_v\(TelenorIdSdk.version)"
        versionString.append("_\(operatingSystem.majorVersion)")
        versionString.append(".\(operatingSystem.minorVersion)")
        versionString.append(".\(operatingSystem.patchVersion)")
        return versionString
    }

    private func getConfigurationAndUrl(endpoint: Endpoint) -> (Configuration, URL) {
        guard let configuration = NetworkService.configuration else {
            fatalError("""
                You must provide configuration before accessing NetworkService.
                Use `.useConfiguration()` before accessing shared instance.
            """)
        }
        let urlComponents = endpoint(configuration)
        guard let url = urlComponents.url else {
            fatalError("An error occured when generating the url at logout() method.")
        }
        return (configuration, url)
    }
    
    private func getLegacyConfigurationAndTokenRefreshUrl() -> (Configuration, URL) {
        guard let configuration = NetworkService.configuration else {
            fatalError("""
                You must provide configuration before accessing NetworkService.
                Use `.useConfiguration()` before accessing shared instance.
            """)
        }
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = Host.getLegacyIdHost(environment: configuration.environment)
        urlComponents.path = "/oauth/token"
        
        guard let url = urlComponents.url else {
            fatalError("An error occured when generating the url at getLegacyConfigurationAndTokenRefreshUrl() method.")
        }
        return (configuration, url)
    }
}
