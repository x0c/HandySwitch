import AppKit
import SwiftUI

@MainActor
final class TogglePanel: NSPanel {
    private var hostingView: NSHostingView<TogglePanelView>?
    private var outsideClickMonitor: Any?
    private var outsideClickLocalMonitor: Any?
    var additionalKeptFrames: () -> [NSRect] = { [] }

    init(model: FeatureController) {
        super.init(
            contentRect: NSRect(origin: .zero, size: AppPreferences.panelSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        let hosting = NSHostingView(rootView: TogglePanelView(model: model, onHeightChange: { [weak self] height in
            self?.resizeContent(height: height)
        }))
        hosting.frame = contentRect(forFrameRect: frame)
        hosting.autoresizingMask = [.width, .height]
        hosting.safeAreaRegions = []
        hostingView = hosting
        contentView = makeChrome(hosting)
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func show(anchor: NSRect?) {
        position(near: anchor)
        orderFrontRegardless()
        makeKey()
        makeFirstResponder(contentView)
        installOutsideClickMonitor()
    }

    func hidePanel() {
        removeOutsideClickMonitor()
        orderOut(nil)
    }

    private func resizeContent(height: CGFloat) {
        let height = ceil(height)
        guard abs(frame.height - height) > 1 else { return }
        var next = frame
        next.origin.y += next.height - height
        next.size.height = height
        setFrame(next, display: true)
    }

    private func position(near anchor: NSRect?) {
        let size = frame.size
        let screens = NSScreen.screens.map(\.frame)
        let visibles = NSScreen.screens.map(\.visibleFrame)
        let fallback = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let origin = PanelPlacement.origin(
            anchor: anchor,
            size: size,
            screens: screens,
            visibleScreens: visibles,
            fallbackVisible: fallback
        )
        setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        let mouseDown: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseDown) { [weak self] _ in
            let point = NSEvent.mouseLocation
            Task { @MainActor in
                self?.handleOutsideMouseDown(at: point, eventWindow: nil)
            }
        }
        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseDown) { [weak self] event in
            guard let self else { return event }
            let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
            self.handleOutsideMouseDown(at: point, eventWindow: event.window)
            return event
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let outsideClickLocalMonitor {
            NSEvent.removeMonitor(outsideClickLocalMonitor)
            self.outsideClickLocalMonitor = nil
        }
    }

    private func handleOutsideMouseDown(at point: NSPoint, eventWindow: NSWindow?) {
        guard isVisible else { return }
        if eventWindow === self { return }
        let kept = [frame] + additionalKeptFrames()
        guard PanelDismiss.shouldHide(click: point, keptFrames: kept) else { return }
        hidePanel()
    }

    private func makeChrome(_ hostingView: NSHostingView<TogglePanelView>) -> NSView {
        let frame = NSRect(origin: .zero, size: AppPreferences.panelSize)
        if #available(macOS 26.0, *) {
            let glass = PanelGlassView(frame: frame, cornerRadius: AppPreferences.panelCornerRadius)
            glass.autoresizingMask = [.width, .height]
            glass.clipsToBounds = true
            glass.contentView = hostingView
            return glass
        }
        let effect = NSVisualEffectView(frame: frame)
        effect.autoresizingMask = [.width, .height]
        effect.material = .menu
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = AppPreferences.panelCornerRadius
        effect.layer?.masksToBounds = true
        effect.addSubview(hostingView)
        hostingView.frame = effect.bounds
        hostingView.autoresizingMask = [.width, .height]
        return effect
    }
}

@available(macOS 26.0, *)
private final class PanelGlassView: NSGlassEffectView {
    private typealias IntegerSetter = @convention(c) (AnyObject, Selector, Int) -> Void
    private let glassCornerRadius: CGFloat

    init(frame frameRect: NSRect, cornerRadius: CGFloat) {
        glassCornerRadius = cornerRadius
        super.init(frame: frameRect)
        applyClearGlass()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("不支持通过归档创建玻璃底板")
    }

    override func layout() {
        super.layout()
        cornerRadius = glassCornerRadius
        applyClearGlass()
    }

    private func applyClearGlass() {
        style = .clear
        tintColor = .clear
        setPrivateIntegerProperty("variant", value: 2)
        setPrivateIntegerProperty("scrimState", value: 0)
        setPrivateIntegerProperty("subduedState", value: 0)
    }

    private func setPrivateIntegerProperty(_ key: String, value: Int) {
        let selectorNames = [
            "set_\(key):",
            "set\(key.prefix(1).uppercased())\(key.dropFirst()):"
        ]
        guard let selectorName = selectorNames.first(where: { responds(to: NSSelectorFromString($0)) }) else {
            return
        }
        let selector = NSSelectorFromString(selectorName)
        let implementation = method(for: selector)
        let setter = unsafeBitCast(implementation, to: IntegerSetter.self)
        setter(self, selector, value)
    }
}
