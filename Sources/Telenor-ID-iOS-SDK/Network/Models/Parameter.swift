import Foundation

enum Parameter: String, Encodable {
    case responseType = "response_type",
        clientId = "client_id",
        redirectUri = "redirect_uri",
        scope = "scope",
        state = "state",
        prompt = "prompt",
        maxAge = "max_age",
        uiLocales = "ui_locales",
        loginHint = "login_hint",
        acrValues = "acr_values",
        claims = "claims",
        accessToken = "access_token",
        tokenType = "token_type",
        expiresIn = "expires_in",
        refreshToken = "refresh_token",
        idToken = "id_token",
        grantType = "grant_type",
        code = "code",
        logoutToken = "logout_token",
        postLogoutRedirectUri = "post_logout_redirect_uri",
        telenordigitalSdkVersion = "telenordigital_sdk_version",
        telenordigitalDid = "telenordigital_did",
        logSessionId = "log_session_id",
        token = "token",
        codeChallenge = "code_challenge",
        codeChallengeMethod = "code_challenge_method",
        codeVerifier = "code_verifier",
        idTokenHint = "id_token_hint"

    func callAsFunction() -> String {
        return self.rawValue
    }
}
