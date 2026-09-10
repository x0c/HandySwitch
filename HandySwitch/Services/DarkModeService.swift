import AppKit
import ApplicationServices
import Foundation
import OSLog

/// 系统外观深色 / 浅色镜像；不持久化到本应用偏好。
@MainActor
@Observable
final class DarkModeService {
    private static let logger = Logger(subsystem: "top.caozc.HandySwitch", category: "DarkMode")
    private static let themeChangedNotification = Notification.Name("AppleInterfaceThemeChangedNotification")

    private(set) var isDarkMode = false
    private(set) var needsAutomationHelp = false
    /// True only after the user refused System Events control — Settings then has an entry.
    private(set) var automationAccessDenied = false
    var onStatusChange: (() -> Void)?

    /// 观察者令牌仅用于移除；deinit 可能离开 MainActor，故用 unsafe。
    nonisolated(unsafe) private var themeObserver: NSObjectProtocol?
    private var toggleGeneration = 0

    init() {
        refreshFromSystem()
        themeObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.themeChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refreshFromSystem()
                self.onStatusChange?()
            }
        }
    }

    deinit {
        if let themeObserver {
            DistributedNotificationCenter.default().removeObserver(themeObserver)
        }
    }

    func refreshFromSystem() {
        isDarkMode = Self.readIsDark()
    }

    func setEnabled(_ enabled: Bool) {
        // 先作废进行中的切换：快速拨回「当前外观」时若 early-return 不 bump，
        // 先前那次异步切换仍会落地，开关与系统外观对不上。
        toggleGeneration += 1
        let generation = toggleGeneration

        if enabled == isDarkMode {
            needsAutomationHelp = false
            automationAccessDenied = false
            return
        }

        Task { [weak self] in
            // Activate on main first so the TCC sheet is not buried for LSUIElement apps.
            await MainActor.run {
                NSApp.activate(ignoringOtherApps: true)
            }

            // 授权窗会阻塞线程，必须离开主线程，否则浮层卡死、系统也不弹窗。
            let status = await Task.detached(priority: .userInitiated) {
                let current = AutomationPermission.currentSystemEventsStatus()
                if AutomationPermission.isAllowed(current) {
                    return current
                }
                if AutomationPermission.isDenied(current) {
                    return current
                }
                return AutomationPermission.requestSystemEventsAccess()
            }.value

            guard let self, generation == self.toggleGeneration else { return }
            Self.logger.info("System Events permission status=\(status)")

            guard AutomationPermission.isAllowed(status) else {
                Self.logger.error("System Events 自动化未授权 status=\(status)")
                self.needsAutomationHelp = true
                self.automationAccessDenied = AutomationPermission.isDenied(status)
                self.refreshFromSystem()
                self.onStatusChange?()
                return
            }

            do {
                try Self.runAppleScript(enabled ? Self.onScript : Self.offScript)
                self.isDarkMode = enabled
                self.needsAutomationHelp = false
                self.automationAccessDenied = false
                self.onStatusChange?()
            } catch {
                Self.logger.error("切换系统深色模式失败：\(error.localizedDescription, privacy: .public)")
                self.needsAutomationHelp = true
                // Script failure after allow is rare; prefer retry over Settings.
                self.automationAccessDenied = false
                self.refreshFromSystem()
                self.onStatusChange?()
            }
        }
    }

    /// Re-request System Events access and apply the intended appearance if allowed.
    func retryAutomationAccess() {
        setEnabled(!isDarkMode)
    }

    private static func readIsDark() -> Bool {
        if let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
            return style.compare("Dark", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        let appearance = NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static let onScript = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to true
            end tell
        end tell
        """

    private static let offScript = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to false
            end tell
        end tell
        """

    private static func runAppleScript(_ source: String) throws {
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw DarkModeError.scriptUnavailable
        }
        _ = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
                ?? errorInfo.description
            throw DarkModeError.scriptFailed(message)
        }
    }
}

private enum DarkModeError: LocalizedError {
    case scriptUnavailable
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .scriptUnavailable:
            return "无法创建外观切换脚本"
        case .scriptFailed(let message):
            return message
        }
    }
}
