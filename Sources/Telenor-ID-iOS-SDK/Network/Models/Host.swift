import Foundation

enum Host: String {
    case idProduction = "id.telenor.no",
        idStaging = "id-test.telenor.no",
        selfServiceProduction = "manage.telenorid.com",
        selfServiceStaging = "manage.telenorid-staging.com",
        selfServiceTest = "manage.telenorid-test.com",
        legacyIdProduction = "signin.telenorid.com",
        legacyIdStaging = "signin.telenorid-staging.com",
        legacyIdTest = "signin.telenorid-test.com"
    
    public func isSelfService() -> Bool {
        return self == .selfServiceProduction
        || self == .selfServiceStaging
        || self == .selfServiceTest
    }
    
    public static func getLegacyIdHost(environment: Environment) -> String {
        switch environment {
        case .production:
            return legacyIdProduction.rawValue
        case .staging:
            return legacyIdStaging.rawValue
        case .test:
            return legacyIdTest.rawValue
        }
    }

    public static func getIdHost(environment: Environment) -> String {
        switch environment {
        case .production:
            return idProduction.rawValue
        case .staging:
            return idStaging.rawValue
        case .test:
            return idStaging.rawValue
        }
    }

    public static func getSelfServiceHost(environment: Environment) -> String {
        switch environment {
        case .production:
            return selfServiceProduction.rawValue
        case .staging:
            return selfServiceStaging.rawValue
        case .test:
            return selfServiceTest.rawValue
        }
    }
    
    public static func getSelfServiceUrlComponents(environment: Environment) -> URLComponents {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = Host.getIdHost(environment: environment)
        return urlComponents
    }
}
