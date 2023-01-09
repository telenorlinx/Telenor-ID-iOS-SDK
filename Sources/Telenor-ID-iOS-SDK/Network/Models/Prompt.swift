import Foundation

public enum Prompt: String {
    case none = "none",
        login = "login",
        noSeam = "no_seam"

    func callAsFunction() -> String {
        return self.rawValue
    }
}
