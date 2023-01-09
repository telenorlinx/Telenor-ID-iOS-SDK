import Foundation

enum Host: String {
    case idProduction = "signin.telenorid.com",
        idStaging = "signin.telenorid-staging.com",
        idTest = "signin.telenorid-test.com",
        selfServiceProduction = "manage.telenorid.com",
        selfServiceStaging = "manage.telenorid-staging.com",
        selfServiceTest = "manage.telenorid-test.com"

    public static func getIdHost(environment: Environment) -> String {
        switch environment {
        case .production:
            return idProduction.rawValue
        case .staging:
            return idStaging.rawValue
        case .test:
            return idTest.rawValue
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
}
