import AppKit
import Foundation
import MacKitUpdater

/// 私有仓尚未配好签名更新源时，禁止自动拉起 Sparkle，否则启动会弹「updater failed」。
/// 配齐 `SUPublicEDKey` + 可用 `SUFeedURL` 后才会真正启动更新器；缺配置时的说明文案留产品侧。
@MainActor
final class AppUpdater: NSObject {
    private let checker = SparkleUpdateChecker(requiresFeedConfiguration: true)

    var isUpdateSessionInProgress: Bool {
        checker.isSessionInProgress
    }

    @objc
    func checkForUpdates(_ sender: Any?) {
        guard checker.isUpdaterAvailable else {
            let alert = NSAlert()
            alert.messageText = String(localized: "updates.unavailable.title")
            alert.informativeText = String(localized: "updates.unavailable.body")
            alert.alertStyle = .informational
            alert.addButton(withTitle: String(localized: "updates.unavailable.ok"))
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        checker.checkForUpdates(sender)
    }
}
