import Foundation

enum DeveloperEvent: String, CaseIterable {
    case buildStarted = "build-started"
    case buildSucceeded = "build-succeeded"
    case buildFailed = "build-failed"
    case testStarted = "test-started"
    case testSucceeded = "test-succeeded"
    case testFailed = "test-failed"
    case cancelled

    var title: String {
        switch self {
        case .buildStarted: return "Собираю…"
        case .buildSucceeded: return "Сборка готова!"
        case .buildFailed: return "Ошибка сборки"
        case .testStarted: return "Проверяю тесты…"
        case .testSucceeded: return "Тесты прошли!"
        case .testFailed: return "Тесты не прошли"
        case .cancelled: return "Задача отменена"
        }
    }

    var isSuccess: Bool { self == .buildSucceeded || self == .testSucceeded }
    var isFailure: Bool { self == .buildFailed || self == .testFailed }
}

/// Informational local events only. Other apps in this login session may post
/// them, so payloads never trigger commands, file access or permission changes.
final class DeveloperEvents: NSObject {
    static let notificationName = Notification.Name("app.pico.desktop.developer-event.v1")
    var onEvent: ((DeveloperEvent) -> Void)?
    private var listening = false

    func start() {
        guard !listening else { return }
        listening = true
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(receive(_:)), name: Self.notificationName,
            object: nil, suspensionBehavior: .drop
        )
    }

    func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
        listening = false
    }

    @objc private func receive(_ notification: Notification) {
        guard listening, notification.userInfo?.isEmpty != false,
              let raw = notification.object as? String,
              let event = DeveloperEvent(rawValue: raw) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.listening else { return }
            self.onEvent?(event)
        }
    }

    deinit { DistributedNotificationCenter.default().removeObserver(self) }
}
