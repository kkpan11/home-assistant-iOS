import Foundation
@testable import Shared

final class MockLocalNotificationDispatcher: LocalNotificationDispatcherProtocol {
    private var lastNotificationSent: LocalNotificationDispatcher.Notification?

    func send(_ notification: LocalNotificationDispatcher.Notification) {
        lastNotificationSent = notification
    }
}
