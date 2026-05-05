import SwiftUI
import Observation

@Observable
@MainActor
final class ToastManager {
    private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, kind: Toast.Kind = .info, duration: Duration = .seconds(3.5)) {
        dismissTask?.cancel()
        current = Toast(message: message, kind: kind)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            if !Task.isCancelled { self?.current = nil }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}
