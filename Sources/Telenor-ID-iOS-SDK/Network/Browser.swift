import Foundation
import AuthenticationServices
import SafariServices

class Browser: NSObject, SFSafariViewControllerDelegate {
    private var configuration: Configuration

    init(_ configuration: Configuration) {
        self.configuration = configuration
    }

    func launch(
        url: URL,
        viewControllerContext: Any?,
        state: String?,
        onComplete: @escaping (OperationStatus, String?, Int?, Error?) -> Void
    ) {
        if #available(iOS 12.0, *) {
            let authenticationSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: configuration.callbackUrlScheme) { (successUrl: URL?, error: Error?) in
                    self.handleCallback(
                        successUrl: successUrl,
                        error: error,
                        state: state,
                        onComplete: onComplete)
            }

            if #available(iOS 13.0, *) {
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
            }
            authenticationSession.start()
            return
        }

        // The drop of older versions support should be considered
        if #available(iOS 11.0, *) {
            let authenticationSession = SFAuthenticationSession(
                url: url,
                callbackURLScheme: configuration.callbackUrlScheme) { (successUrl: URL?, error: Error?) in
                    self.handleCallback(
                        successUrl: successUrl,
                        error: error,
                        state: state,
                        onComplete: onComplete)
            }

            authenticationSession.start()
            return
        }

        if #available(iOS 9.0, *) {
            let safariViewController = SFSafariViewController(url: url as URL)
            safariViewController.delegate = self
            UIApplication.shared.tdcTopViewController?.present(safariViewController, animated: true, completion: nil)
            return
        }

        UIApplication.shared.open(url as URL)
    }

    private func handleCallback(
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

        TelenorIdSdk.networkService().getAccessToken(code: code, onComplete: onComplete)
    }

    private func executeOnComplete(
        operationStatus: OperationStatus,
        error: Error?,
        onComplete: @escaping (OperationStatus, String?, Int?, Error?) -> Void
    ) {
        if #available(iOS 9.0, *) {
            UIApplication.shared.tdcTopViewController?.dismiss(animated: true) {
                onComplete(operationStatus, nil, nil, error)
            }
            return
        }
        onComplete(operationStatus, nil, nil, error)
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
