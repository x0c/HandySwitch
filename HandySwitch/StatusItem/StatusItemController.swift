import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let launchAtLoginItem: NSMenuItem
    private let onOpenMainWindow: () -> Void
    private let onTogglePanel: () -> Void
    private let onCheckForUpdates: () -> Void
    private let onQuit: () -> Void

    var isVisible: Bool {
        get { statusItem.isVisible }
        set { statusItem.isVisible = newValue }
    }

    init(
        onOpenMainWindow: @escaping () -> Void,
        onTogglePanel: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onOpenMainWindow = onOpenMainWindow
        self.onTogglePanel = onTogglePanel
        self.onCheckForUpdates = onCheckForUpdates
        self.onQuit = onQuit

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        launchAtLoginItem = NSMenuItem(
            title: String(localized: "menu.launchAtLogin"),
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        super.init()

        launchAtLoginItem.target = self
        configureMenu()
        configureButton()
        refreshLaunchAtLoginState()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(named: "StatusBarIcon")
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        button.image = image
        button.image?.isTemplate = true
        button.setAccessibilityLabel(String(localized: "status.item.accessibility"))
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.focusRingType = .none
    }

    private func configureMenu() {
        let openItem = NSMenuItem(
            title: String(localized: "menu.openMainWindow"),
            action: #selector(openMainWindow(_:)),
            keyEquivalent: ""
        )
        openItem.target = self

        let checkForUpdatesItem = NSMenuItem(
            title: String(localized: "menu.checkForUpdates"),
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = self

        let quitItem = NSMenuItem(
            title: String(localized: "menu.quit"),
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self

        menu.items = [
            openItem,
            .separator(),
            launchAtLoginItem,
            .separator(),
            checkForUpdatesItem,
            quitItem
        ]
    }

    func buttonScreenFrame() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    @objc
    private func handleClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            onTogglePanel()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            refreshLaunchAtLoginState()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            onTogglePanel()
        }
    }

    @objc
    private func openMainWindow(_ sender: Any?) {
        onOpenMainWindow()
    }

    @objc
    private func toggleLaunchAtLogin(_ sender: Any?) {
        let manager = LaunchAtLoginManager.shared
        manager.setEnabled(!manager.isEnabled)
        refreshLaunchAtLoginState()
    }

    @objc
    private func checkForUpdates(_ sender: Any?) {
        onCheckForUpdates()
    }

    @objc
    private func quit(_ sender: Any?) {
        onQuit()
    }

    private func refreshLaunchAtLoginState() {
        LaunchAtLoginManager.shared.refresh()
        switch LaunchAtLoginManager.shared.status {
        case .on:
            launchAtLoginItem.state = .on
        case .needsApproval:
            launchAtLoginItem.state = .mixed
        case .off:
            launchAtLoginItem.state = .off
        }
    }
}
