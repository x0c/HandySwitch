import AppKit
import ApplicationServices
import Foundation
import OSLog

/// 自动化（Apple Events）权限：深色模式要控制 System Events。
enum AutomationPermission {
    nonisolated private static let systemEventsBundleID = "com.apple.systemevents"
    nonisolated private static let logger = Logger(subsystem: "top.caozc.HandySwitch", category: "Automation")

    /// Benign automation event class/id ('core'/'getd') — wildcards alone may not trigger TCC.
    nonisolated private static let probeEventClass = AEEventClass(0x636F_7265)
    nonisolated private static let probeEventID = AEEventID(0x6765_7464)

    /// 不弹窗：查当前是否已允许控制 System Events。
    nonisolated static func currentSystemEventsStatus() -> OSStatus {
        ensureSystemEventsRunning()
        return determinePermission(askUserIfNeeded: false)
    }

    /// 若尚未决定则弹出系统授权窗（会阻塞当前线程，须在后台调用）。
    nonisolated static func requestSystemEventsAccess() -> OSStatus {
        ensureSystemEventsRunning()
        // Menu bar / LSUIElement apps often never surface the TCC sheet unless activated.
        DispatchQueue.main.sync {
            let previous = NSApp.activationPolicy()
            if previous != .regular {
                NSApp.setActivationPolicy(.regular)
            }
            NSApp.activate(ignoringOtherApps: true)
            // Restore after a short delay so Dock stays empty once the sheet is up.
            if previous != .regular {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    NSApp.setActivationPolicy(previous)
                }
            }
        }

        var status = determinePermission(askUserIfNeeded: true)
        logger.info("AEDetermine ask=true status=\(status)")

        // AEDetermine alone can return without a sheet on some builds; sending a real event forces TCC.
        if !isAllowed(status), !isDenied(status) {
            status = triggerConsentViaAppleScript()
            logger.info("AppleScript consent probe status=\(status)")
        }
        return status
    }

    nonisolated static func isAllowed(_ status: OSStatus) -> Bool {
        status == noErr
    }

    nonisolated static func isDenied(_ status: OSStatus) -> Bool {
        status == OSStatus(errAEEventNotPermitted)
    }

    nonisolated static func needsUserConsent(_ status: OSStatus) -> Bool {
        status == OSStatus(errAEEventWouldRequireUserConsent) || status == OSStatus(procNotFound)
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
        var address = AEDesc(descriptorType: typeNull, dataHandle: nil)
        let created = systemEventsBundleID.withCString { pointer in
            AECreateDesc(typeApplicationBundleID, pointer, strlen(pointer), &address)
        }
        guard created == noErr else {
            logger.error("AECreateDesc failed status=\(created)")
            return OSStatus(errAEEventNotPermitted)
        }
        defer { AEDisposeDesc(&address) }

        return AEDeterminePermissionToAutomateTarget(
            &address,
            probeEventClass,
            probeEventID,
            askUserIfNeeded
        )
    }

    /// Execute a no-op appearance read so TCC must show the consent sheet for this binary.
    nonisolated private static func triggerConsentViaAppleScript() -> OSStatus {
        let source = """
            tell application "System Events"
                tell appearance preferences
                    get dark mode
                end tell
            end tell
            """
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return OSStatus(errAEEventNotPermitted)
        }
        _ = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = (errorInfo[NSAppleScript.errorNumber] as? Int)
                ?? Int(errAEEventNotPermitted)
            logger.error("consent AppleScript failed code=\(code) info=\(String(describing: errorInfo), privacy: .public)")
            return OSStatus(code)
        }
        return noErr
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
        Thread.sleep(forTimeInterval: 0.2)
    }
}
