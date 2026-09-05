import AppKit
import Foundation
import Sparkle

/// 私有仓尚未配好签名更新源时，禁止自动拉起 Sparkle，否则启动会弹「updater failed」。
/// 配齐 `SUPublicEDKey` + 可用 `SUFeedURL` 后才会真正启动更新器。
@MainActor
final class AppUpdater: NSObject {
    private var controller: SPUStandardUpdaterController?

    override init() {
        super.init()
        if Self.hasUsableSparkleConfiguration {
            controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        }
    }

    var isUpdateSessionInProgress: Bool {
        controller?.updater.sessionInProgress ?? false
    }

    @objc
    func checkForUpdates(_ sender: Any?) {
        if let updater = controller?.updater {
            updater.checkForUpdates()
            return
        }
        let alert = NSAlert()
        alert.messageText = String(localized: "updates.unavailable.title")
        alert.informativeText = String(localized: "updates.unavailable.body")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "updates.unavailable.ok"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static var hasUsableSparkleConfiguration: Bool {
        let bundle = Bundle.main
        let feed = (bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let key = (bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !feed.isEmpty && !key.isEmpty
    }
}
