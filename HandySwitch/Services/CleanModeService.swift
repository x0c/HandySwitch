import AppKit
import ApplicationServices
import Carbon
import CoreGraphics
import Foundation
import IOKit.pwr_mgt
import Observation
import OSLog
import SwiftUI

/// 全黑遮罩 + 事件拦截。退出：仅按住 Esc 约 3 秒。必须吞掉媒体键，禁止注册 Now Playing。
@MainActor
@Observable
final class CleanModeService {
    private static let logger = Logger(subsystem: "top.caozc.HandySwitch", category: "CleanMode")
    private static let escapeHoldSeconds = 3
    private static let nullAssertionID = IOPMAssertionID(0)

    private(set) var isActive = false

    var onEnded: (() -> Void)?

    private var overlayWindows: [NSWindow] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var contextPointer: UnsafeMutableRawPointer?
    private var previousPresentationOptions: NSApplication.PresentationOptions?
    private var cursorHidden = false
    private var idleAssertionID = CleanModeService.nullAssertionID
    private var escapeHoldTimer: Timer?
    private var escapeHoldRemaining = 0
    /// 松键取消后仍可能有已排队的 tick Task；用代际作废，避免松 Esc 后仍退出。
    private var escapeHoldGeneration = 0
    private let hintModel = OverlayHintModel()
    private var screenObserver: NSObjectProtocol?
    private var isStopping = false

    @discardableResult
    func start() -> Bool {
        guard !isActive else { return true }
        guard AccessibilityPermission.isTrusted() else {
            AccessibilityPermission.requestTrust(prompt: true)
            return false
        }

        let context = EventTapContext(
            onEscapeKeyDown: { [weak self] in
                Task { @MainActor in self?.beginEscapeHold() }
            },
            onEscapeKeyUp: { [weak self] in
                Task { @MainActor in self?.cancelEscapeHold() }
            },
            onTapDisabled: { [weak self] in
                Task { @MainActor in self?.recoverOrStop() }
            }
        )
        let pointer = UnsafeMutableRawPointer(Unmanaged.passRetained(context).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: cleanModeInterceptedEventMask,
            callback: cleanModeEventTapCallback,
            userInfo: pointer
        ) else {
            Unmanaged<EventTapContext>.fromOpaque(pointer).release()
            Self.logger.error("无法创建清洁模式事件拦截")
            return false
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            Unmanaged<EventTapContext>.fromOpaque(pointer).release()
            return false
        }

        eventTap = tap
        runLoopSource = source
        contextPointer = pointer
        context.eventTap = tap

        previousPresentationOptions = NSApp.presentationOptions
        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching]

        beginIdleLockPrevention()
        rebuildOverlays()
        hideCursor()
        updateHints()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuildOverlays() }
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isActive = true
        isStopping = false
        return true
    }

    func stop(reason: EndReason = .userRequested) {
        guard isActive || eventTap != nil else { return }
        guard !isStopping else { return }
        isStopping = true

        cancelEscapeHold()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        closeOverlays()

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil

        if let contextPointer {
            Unmanaged<EventTapContext>.fromOpaque(contextPointer).release()
            self.contextPointer = nil
        }

        showCursorIfNeeded()
        releaseIdleLockPrevention()
        if let previousPresentationOptions {
            NSApp.presentationOptions = previousPresentationOptions
            self.previousPresentationOptions = nil
        }

        isActive = false
        isStopping = false
        Self.logger.info("清洁模式结束 reason=\(String(describing: reason))")
        onEnded?()
    }

    enum EndReason {
        case userRequested
        case escapeHold
        case tapFailed
    }

    private func beginEscapeHold() {
        guard escapeHoldTimer == nil else { return }
        escapeHoldGeneration += 1
        let generation = escapeHoldGeneration
        escapeHoldRemaining = Self.escapeHoldSeconds
        updateHints()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickEscapeHold(generation: generation)
            }
        }
        escapeHoldTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func cancelEscapeHold() {
        // 作废已排队的 tick Task：仅判 timer!=nil 不够——松键再按会挂上新 timer，
        // 旧 tick 仍会改 remaining 甚至误退出。
        escapeHoldGeneration += 1
        escapeHoldTimer?.invalidate()
        escapeHoldTimer = nil
        escapeHoldRemaining = 0
        updateHints()
    }

    private func tickEscapeHold(generation: Int) {
        guard generation == escapeHoldGeneration else { return }
        if escapeHoldRemaining > 1 {
            escapeHoldRemaining -= 1
            updateHints()
            return
        }
        cancelEscapeHold()
        stop(reason: .escapeHold)
    }

    private func recoverOrStop() {
        guard let eventTap else {
            stop(reason: .tapFailed)
            return
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        if !CGEvent.tapIsEnabled(tap: eventTap) {
            stop(reason: .tapFailed)
        }
    }

    private func updateHints() {
        if escapeHoldRemaining > 0 {
            hintModel.primary = "Hold Esc… \(escapeHoldRemaining)s"
        } else {
            hintModel.primary = "Hold Esc \(Self.escapeHoldSeconds)s to exit"
        }
    }

    private func rebuildOverlays() {
        closeOverlays()
        let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = level
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isMovable = false
            window.isReleasedWhenClosed = false
            window.setFrame(screen.frame, display: true)
            window.contentView = NSHostingView(rootView: OverlayHintView(model: hintModel))
            window.orderFrontRegardless()
            overlayWindows.append(window)
        }
        overlayWindows.first?.makeKeyAndOrderFront(nil)
    }

    private func closeOverlays() {
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
    }

    private func beginIdleLockPrevention() {
        guard idleAssertionID == Self.nullAssertionID else { return }
        var id = Self.nullAssertionID
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "HandySwitch Clean Mode" as CFString,
            &id
        )
        if result == kIOReturnSuccess {
            idleAssertionID = id
        }
    }

    private func releaseIdleLockPrevention() {
        guard idleAssertionID != Self.nullAssertionID else { return }
        IOPMAssertionRelease(idleAssertionID)
        idleAssertionID = Self.nullAssertionID
    }

    private func hideCursor() {
        guard !cursorHidden else { return }
        NSCursor.hide()
        cursorHidden = true
    }

    private func showCursorIfNeeded() {
        guard cursorHidden else { return }
        NSCursor.unhide()
        cursorHidden = false
    }

}

@MainActor
@Observable
private final class OverlayHintModel {
    var primary = "Hold Esc 3s to exit"
}

private struct OverlayHintView: View {
    @Bindable var model: OverlayHintModel

    var body: some View {
        ZStack {
            Color.black
            Text(model.primary)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

/// NSEvent.EventType.systemDefined —— 媒体键走这条。
private let cleanModeSystemDefinedEventType = CGEventType(rawValue: 14)!
private let cleanModeEscapeKeyCode = UInt16(kVK_Escape)

private let cleanModeInterceptedEventMask: CGEventMask = {
    let types: [CGEventType] = [
        .keyDown, .keyUp, .flagsChanged,
        .mouseMoved,
        .leftMouseDown, .leftMouseUp, .leftMouseDragged,
        .rightMouseDown, .rightMouseUp, .rightMouseDragged,
        .otherMouseDown, .otherMouseUp, .otherMouseDragged,
        .scrollWheel,
        cleanModeSystemDefinedEventType
    ]
    return types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << UInt64($1.rawValue)) }
}()

private let cleanModeEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let context = Unmanaged<EventTapContext>.fromOpaque(userInfo).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        context.onTapDisabled()
        return Unmanaged.passUnretained(event)
    }

    // 吞掉媒体键 / 系统定义键，避免触发音乐播放
    if type == cleanModeSystemDefinedEventType {
        return nil
    }

    switch type {
    case .keyDown:
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let control = flags.contains(.maskControl)
        let command = flags.contains(.maskCommand)
        let option = flags.contains(.maskAlternate)
        let shift = flags.contains(.maskShift)

        // 仅无修饰键的 Esc 开始计时；⌃⌘Esc 等其它组合一律吞掉、不退出
        if keyCode == cleanModeEscapeKeyCode, !control, !command, !option, !shift {
            context.onEscapeKeyDown()
        }
        return nil
    case .keyUp:
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if keyCode == cleanModeEscapeKeyCode {
            context.onEscapeKeyUp()
        }
        return nil
    default:
        return nil
    }
}

/// 事件回调在非主线程；用不可变闭包转发回主线程。
private final class EventTapContext: @unchecked Sendable {
    let onEscapeKeyDown: () -> Void
    let onEscapeKeyUp: () -> Void
    let onTapDisabled: () -> Void
    var eventTap: CFMachPort?

    init(
        onEscapeKeyDown: @escaping () -> Void,
        onEscapeKeyUp: @escaping () -> Void,
        onTapDisabled: @escaping () -> Void
    ) {
        self.onEscapeKeyDown = onEscapeKeyDown
        self.onEscapeKeyUp = onEscapeKeyUp
        self.onTapDisabled = onTapDisabled
    }
}
