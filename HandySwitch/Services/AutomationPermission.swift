import AppKit
import ApplicationServices
import Foundation

/// 自动化（Apple Events）权限：深色模式要控制 System Events。
enum AutomationPermission {
    nonisolated private static let systemEventsBundleID = "com.apple.systemevents"

    /// 不弹窗：查当前是否已允许控制 System Events。
    nonisolated static func currentSystemEventsStatus() -> OSStatus {
        ensureSystemEventsRunning()
        return determinePermission(askUserIfNeeded: false)
    }

    /// 若尚未决定则弹出系统授权窗（会阻塞当前线程，须在后台调用）。
    nonisolated static func requestSystemEventsAccess() -> OSStatus {
        ensureSystemEventsRunning()
        return determinePermission(askUserIfNeeded: true)
    }

    nonisolated static func isAllowed(_ status: OSStatus) -> Bool {
        status == noErr
    }

    nonisolated static func isDenied(_ status: OSStatus) -> Bool {
        status == OSStatus(errAEEventNotPermitted)
    }

    @MainActor
    static func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            "x-apple.systempreferences:com.apple.Localization-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.security",
        ]
        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    nonisolated private static func determinePermission(askUserIfNeeded: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: systemEventsBundleID)
        guard let aeDesc = target.aeDesc else {
            return OSStatus(errAEEventNotPermitted)
        }
        return AEDeterminePermissionToAutomateTarget(
            aeDesc,
            typeWildCard,
            typeWildCard,
            askUserIfNeeded
        )
    }

    /// System Events 未运行时权限查询会返回 procNotFound，先拉起后台进程。
    nonisolated private static func ensureSystemEventsRunning() {
        let running = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == systemEventsBundleID
        }
        guard !running else { return }
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: systemEventsBundleID
        ) else {
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false
        let semaphore = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2)
        Thread.sleep(forTimeInterval: 0.15)
    }
}
