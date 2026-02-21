import Foundation

struct AppError: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    init(from error: Error) {
        self.title = "Error"
        self.message = error.localizedDescription
    }
}
