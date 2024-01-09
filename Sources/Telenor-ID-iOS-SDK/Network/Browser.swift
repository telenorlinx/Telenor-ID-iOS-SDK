import Foundation
import AuthenticationServices
import SafariServices

class Browser: NSObject, SFSafariViewControllerDelegate {
    private var configuration: Configuration

    init(_ configuration: Configuration) {
        self.configuration = configuration
    }

    func launch(
        scope: Set<String>,
        codeVerifier: String,
        url: URL,
        viewControllerContext: Any?,
        state: String?,
        onComplete: @escaping (OperationStatus, String?, Int?, Error?) -> Void
    ) {
        let authenticationSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: configuration.callbackUrlScheme) { (successUrl: URL?, error: Error?) in
                self.handleCallback(
                    scope: scope,
                    codeVerifier: codeVerifier,
                    successUrl: successUrl,
                    error: error,
                    state: state,
                    onComplete: onComplete)
        }

        // As there is support for versions below 13 now, this way of providing the
        // swiftlint:disable force_cast
        if viewControllerContext is ASWebAuthenticationPresentationContextProviding {
            authenticationSession.presentationContextProvider = (
                viewControllerContext as! ASWebAuthenticationPresentationContextProviding
            )
        } else {
            fatalError("""
                iOS 13 and higher requires to provide view controller,
                that implements ASWebAuthenticationPresentationContextProviding protocol
            """)
        }
        
        authenticationSession.start()
    }

    private func handleCallback(
        scope: Set<String>,
        codeVerifier: String,
        successUrl: URL?,
        error: Error?,
        state: String?,
        onComplete: @escaping (OperationStatus, String?, Int?, Error?) -> Void
    ) {
        guard error == nil else {
            executeOnComplete(
                operationStatus: OperationStatus.failure,
                error: error,
                onComplete: onComplete)
            return
        }

        guard let stringUrl = successUrl?.absoluteString else {
            executeOnComplete(
                operationStatus: OperationStatus.failure,
                error: error,
                onComplete: onComplete)
            return
        }

        guard let url = URLComponents(string: stringUrl) else {
            executeOnComplete(
                operationStatus: OperationStatus.failure,
                error: error,
                onComplete: onComplete)
            return
        }

        let stateFromRedirectUrl = self.getParameter(url: url, parameter: Parameter.state)
        if state != stateFromRedirectUrl {
            // TODO(serhii): not equal state parameters error
            executeOnComplete(
                operationStatus: OperationStatus.failure,
                error: error,
                onComplete: onComplete)
            return
        }

        guard let code = self.getParameter(url: url, parameter: Parameter.code) else {
            executeOnComplete(
                operationStatus: OperationStatus.failure,
                error: error,
                onComplete: onComplete)
            return
        }

        TelenorIdSdk.networkService().getAccessToken(
            scope: scope,
            codeVerifier: codeVerifier,
            code: code,
            onComplete: onComplete
        )
    }

    private func executeOnComplete(
        operationStatus: OperationStatus,
        error: Error?,
        onComplete: @escaping (OperationStatus, String?, Int?, Error?) -> Void
    ) {
        UIApplication.shared.tdcTopViewController?.dismiss(animated: true) {
            onComplete(operationStatus, nil, nil, error)
        }
        return
    }

    private func getParameter(url: URLComponents, parameter: Parameter) -> String? {
        return url.queryItems?.first { $0.name == parameter.rawValue }?.value
    }
}

private extension UIApplication {
    var tdcTopViewController: UIViewController? {
        guard let rootViewController = keyWindow?.rootViewController else {
            return nil
        }

        var pointedViewController: UIViewController? = rootViewController

        while  pointedViewController?.presentedViewController != nil {
            switch pointedViewController?.presentedViewController {
            case let navagationController as UINavigationController:
                pointedViewController = navagationController.viewControllers.last
            case let tabBarController as UITabBarController:
                pointedViewController = tabBarController.selectedViewController
            default:
                pointedViewController = pointedViewController?.presentedViewController
            }
        }

        return pointedViewController
    }
}
