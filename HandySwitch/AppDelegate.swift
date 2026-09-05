import AppKit
import MacKitCore
import MacKitLifecycle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) static weak var shared: AppDelegate?

    private var panel: TogglePanel?
    private var statusItemController: StatusItemController?
    private var commaMonitor: Any?
    private let appUpdater = AppUpdater()
    private let terminationGuard = TerminationGuard()
    private let featureController = FeatureController.shared

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        // 图标即主入口：清掉历史显隐偏好。
        UserDefaults.standard.removeObject(forKey: "menuBarIconVisible")
        terminationGuard.isUpdateSessionInProgress = { [weak self] in
            self?.appUpdater.isUpdateSessionInProgress ?? false
        }

        let panel = TogglePanel(model: featureController)
        panel.orderOut(nil)
        self.panel = panel

        statusItemController = StatusItemController(
            onOpenMainWindow: { [weak self] in self?.showMainWindow() },
            onTogglePanel: { [weak self] in self?.togglePanel() },
            onCheckForUpdates: { [weak appUpdater] in appUpdater?.checkForUpdates(nil) },
            onQuit: { [weak self] in self?.requestTermination() }
        )
        panel.additionalKeptFrames = { [weak statusItemController] in
            statusItemController?.buttonScreenFrame().map { [$0] } ?? []
        }
        statusItemController?.isVisible = true

        featureController.startPersistedFeatures()

        commaMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let command = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
            if command, event.charactersIgnoringModifiers == "," {
                SettingsWindowController.shared.show()
                return nil
            }
            return event
        }

        // 图标始终可见；登录项拉起禁止弹设置窗。
        let isLoginLaunch = LoginLaunchDetector.isLaunchedAsLoginItem
        if MenuBarReopenPolicy.shouldShowRecoveryWindow(
            iconVisible: true,
            isLoginLaunch: isLoginLaunch
        ) {
            showMainWindow()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        terminationGuard.shouldTerminate() ? .terminateNow : .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 图标始终可见，reopen 不因隐藏策略弹窗；需要设置时用户点「打开主窗口」。
        _ = MenuBarReopenPolicy.presentation(
            iconVisible: true,
            isReopenOrLaunch: true,
            isLoginLaunch: false
        )
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        featureController.prepareForTermination()
        if let commaMonitor {
            NSEvent.removeMonitor(commaMonitor)
        }
    }

    func requestTermination(terminate: () -> Void = { NSApplication.shared.terminate(nil) }) {
        terminationGuard.allowTermination = true
        terminate()
    }

    func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let panel else { return }
        featureController.refreshDarkModeFromSystem()
        let anchor = statusItemController?.buttonScreenFrame()
        panel.show(anchor: anchor)
    }

    func showMainWindow() {
        panel?.hidePanel()
        SettingsWindowController.shared.show()
    }

    func checkForUpdates() {
        appUpdater.checkForUpdates(nil)
    }
}
