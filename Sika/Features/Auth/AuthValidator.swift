import Foundation

enum AuthValidator {
    private static let emailRegex = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#

    static func validateEmail(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Enter your email" }
        if trimmed.range(of: emailRegex, options: .regularExpression) == nil {
            return "Enter a valid email"
        }
        return nil
    }

    static func validatePassword(_ password: String) -> String? {
        if password.isEmpty { return "Enter your password" }
        if password.count < 6 { return "Password must be at least 6 characters" }
        return nil
    }

    static func validateName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 2 { return "Enter your full name" }
        return nil
    }
}
