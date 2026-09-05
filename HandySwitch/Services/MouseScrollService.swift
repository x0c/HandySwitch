import ApplicationServices
import AppKit
import CoreGraphics
import Foundation
import OSLog
import QuartzCore

/// 鼠标滚轮：反转与/或平滑。触控板不动。
/// 平滑投递对齐 Mos：复制原事件 → 写 point delta → continuous=1 → `postToPid`。
/// 拦截对齐 Mos：`cgAnnotatedSessionEventTap` + `tailAppendEventTap`。
/// 默认不写 scrollPhase（对应 Mos 的 smoothSimTrackpad=false）。
nonisolated final class MouseScrollService: @unchecked Sendable {
    static let shared = MouseScrollService()

    private static let logger = Logger(subsystem: "top.caozc.HandySwitch", category: "MouseScroll")

    private let lock = NSLock()
    private var reverseEnabled = false
    private var smoothEnabled = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let poster = SmoothScrollPoster()

    private init() {}

    var isReverseEnabled: Bool {
        lock.lock(); defer { lock.unlock() }
        return reverseEnabled
    }

    var isSmoothEnabled: Bool {
        lock.lock(); defer { lock.unlock() }
        return smoothEnabled
    }

    @discardableResult
    func setReverseEnabled(_ enabled: Bool) -> Bool {
        lock.lock()
        reverseEnabled = enabled
        lock.unlock()
        return syncTap()
    }

    @discardableResult
    func setSmoothEnabled(_ enabled: Bool) -> Bool {
        lock.lock()
        smoothEnabled = enabled
        let turnOff = !enabled
        lock.unlock()
        if turnOff {
            poster.stop()
        }
        return syncTap()
    }

    func stopAll() {
        lock.lock()
        reverseEnabled = false
        smoothEnabled = false
        lock.unlock()
        poster.stop()
        tearDownTap()
    }

    func handleScrollEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if MouseScrollMarkers.isSynthetic(event) {
            return Unmanaged.passUnretained(event)
        }
        if MouseScrollDetector.isTrackpad(event) {
            return Unmanaged.passUnretained(event)
        }

        lock.lock()
        let reverse = reverseEnabled
        let smooth = smoothEnabled
        lock.unlock()

        guard reverse || smooth else {
            return Unmanaged.passUnretained(event)
        }

        var y = MouseScrollDetector.usableDelta(event, axis: .y)
        var x = MouseScrollDetector.usableDelta(event, axis: .x)
        if y == 0, x == 0 {
            return Unmanaged.passUnretained(event)
        }

        if reverse {
            y = -y
            x = -x
        }

        if smooth {
            // Mos：过小的格滚归一到 step，再乘 speed 进缓冲
            y = MouseScrollDetector.normalize(y, step: SmoothScrollPoster.step)
            x = MouseScrollDetector.normalize(x, step: SmoothScrollPoster.step)
            if poster.enqueue(event: event, y: y, x: x) {
                return nil
            }
            // 拿不到目标进程时放行原事件，避免吞掉却发不出
            return Unmanaged.passUnretained(event)
        }

        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(-event.getIntegerValueField(.scrollWheelEventDeltaAxis1)))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(-event.getIntegerValueField(.scrollWheelEventDeltaAxis2)))
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: -event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1))
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: -event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2))
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1))
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2))
        return Unmanaged.passUnretained(event)
    }

    func reenableTapIfNeeded() {
        lock.lock()
        let tap = eventTap
        lock.unlock()
        guard let tap, CFMachPortIsValid(tap) else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            Self.logger.error("滚轮拦截被系统关掉，正在重新启用")
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func syncTap() -> Bool {
        lock.lock()
        let needTap = reverseEnabled || smoothEnabled
        let hasTap = eventTap != nil
        lock.unlock()

        if !needTap {
            tearDownTap()
            return true
        }
        if hasTap {
            return true
        }
        return startTap()
    }

    private func startTap() -> Bool {
        guard AccessibilityPermission.isTrusted() else {
            DispatchQueue.main.async {
                AccessibilityPermission.requestTrust(prompt: true)
            }
            return false
        }
        // Mos：annotated session + tailAppend，才能拿到可靠的目标 PID
        guard let tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: mouseScrollEventMask,
            callback: mouseScrollEventTapCallback,
            userInfo: nil
        ) else {
            Self.logger.error("无法创建滚轮事件拦截")
            return false
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }
        lock.lock()
        eventTap = tap
        runLoopSource = source
        lock.unlock()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Self.logger.info("滚轮拦截已启动（annotated session / Mos）")
        return true
    }

    private func tearDownTap() {
        lock.lock()
        let tap = eventTap
        let source = runLoopSource
        eventTap = nil
        runLoopSource = nil
        lock.unlock()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
}

enum MouseScrollMarkers {
    nonisolated static let syntheticUserData: Int64 = 0x4853_4D4F_4F54_48

    nonisolated static func markSynthetic(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: syntheticUserData)
    }

    nonisolated static func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == syntheticUserData
    }
}

enum MouseScrollDetector {
    enum Axis { case y, x }

    nonisolated static func isTrackpad(_ event: CGEvent) -> Bool {
        if event.getDoubleValueField(.scrollWheelEventMomentumPhase) != 0 { return true }
        if event.getDoubleValueField(.scrollWheelEventScrollPhase) != 0 { return true }
        if event.getDoubleValueField(.scrollWheelEventScrollCount) != 0 { return true }
        return false
    }

    nonisolated static func usableDelta(_ event: CGEvent, axis: Axis) -> Double {
        let point: Double
        let fixedPt: Double
        let line: Int64
        switch axis {
        case .y:
            point = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
            fixedPt = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
            line = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        case .x:
            point = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
            fixedPt = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
            line = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        }
        if point != 0 { return point }
        if fixedPt != 0 { return fixedPt }
        if line != 0 { return Double(line) }
        return 0
    }

    /// Mos：可用值幅度小于 step 时归一到 step（保留符号）
    nonisolated static func normalize(_ value: Double, step: Double) -> Double {
        guard value != 0 else { return 0 }
        if abs(value) < step {
            return value > 0 ? step : -step
        }
        return value
    }
}

private nonisolated let mouseScrollEventMask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)

private nonisolated let mouseScrollEventTapCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MouseScrollService.shared.reenableTapIfNeeded()
        return Unmanaged.passUnretained(event)
    }
    guard type == .scrollWheel else {
        return Unmanaged.passUnretained(event)
    }
    return MouseScrollService.shared.handleScrollEvent(event)
}

/// 插值与投递对齐 Mos（不含按应用配置 / simTrackpad 相位）。
nonisolated final class SmoothScrollPoster: @unchecked Sendable {
    /// Mos 默认 OPTIONS_SCROLL_DEFAULT
    static let step = 33.6
    private static let speed = 2.70
    /// duration=4.35 → generateDurationTransition ≈ 0.085
    private static let durationTransition = 0.085
    private static let deadZone = 1.0
    private static let logger = Logger(subsystem: "top.caozc.HandySwitch", category: "SmoothScroll")

    private let lock = NSLock()
    private let postQueue = DispatchQueue(label: "top.caozc.HandySwitch.smoothScroll.post", qos: .userInteractive)
    private var bufferY = 0.0
    private var bufferX = 0.0
    private var currentY = 0.0
    private var currentX = 0.0
    private var displayLink: CVDisplayLink?
    private var eventTemplate: CGEvent?
    private var targetPID: pid_t = 0

    @discardableResult
    func enqueue(event: CGEvent, y: Double, x: Double) -> Bool {
        let pid = Self.resolveTargetPID(from: event)
        guard let copy = event.copy() else {
            Self.logger.error("复制滚轮事件失败")
            return false
        }
        guard pid != 0 else {
            Self.logger.error("无法解析滚轮目标进程，放弃平滑本帧")
            return false
        }

        lock.lock()
        eventTemplate = copy
        targetPID = pid
        if y * bufferY > 0 {
            bufferY += y * Self.speed
        } else if y != 0 {
            bufferY = y * Self.speed
            currentY = 0
        }
        if x * bufferX > 0 {
            bufferX += x * Self.speed
        } else if x != 0 {
            bufferX = x * Self.speed
            currentX = 0
        }
        lock.unlock()
        startLinkIfNeeded()
        return true
    }

    func stop() {
        lock.lock()
        bufferY = 0
        bufferX = 0
        currentY = 0
        currentX = 0
        eventTemplate = nil
        targetPID = 0
        let link = displayLink
        displayLink = nil
        lock.unlock()
        if let link {
            CVDisplayLinkStop(link)
        }
    }

    private func startLinkIfNeeded() {
        lock.lock()
        if displayLink != nil {
            lock.unlock()
            return
        }
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else {
            lock.unlock()
            Self.logger.error("CVDisplayLink 创建失败")
            return
        }
        displayLink = link
        lock.unlock()

        let unmanagedSelf = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, context -> CVReturn in
            guard let context else { return kCVReturnSuccess }
            Unmanaged<SmoothScrollPoster>.fromOpaque(context).takeUnretainedValue().tick()
            return kCVReturnSuccess
        }, unmanagedSelf)
        CVDisplayLinkStart(link)
    }

    private func tick() {
        lock.lock()
        let frameY = (bufferY - currentY) * Self.durationTransition
        let frameX = (bufferX - currentX) * Self.durationTransition
        currentY += frameY
        currentX += frameX
        let residual = max(abs(bufferY - currentY), abs(bufferX - currentX))
        let output = max(abs(frameY), abs(frameX))
        let shouldStop = residual <= Self.deadZone && output <= Self.deadZone
        let template = eventTemplate
        let pid = targetPID
        if shouldStop {
            bufferY = 0
            bufferX = 0
            currentY = 0
            currentX = 0
        }
        lock.unlock()

        if output > Self.deadZone, let template, pid != 0 {
            postToTarget(template: template, pid: pid, y: frameY, x: frameX)
        }

        if shouldStop {
            lock.lock()
            let link = displayLink
            displayLink = nil
            lock.unlock()
            if let link {
                CVDisplayLinkStop(link)
            }
        }
    }

    private func postToTarget(template: CGEvent, pid: pid_t, y: Double, x: Double) {
        guard let event = template.copy() else { return }
        // Mos：只改 point delta + continuous；不写 scrollPhase；不新建 session 事件
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: y)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: x)
        event.setDoubleValueField(.scrollWheelEventIsContinuous, value: 1.0)
        MouseScrollMarkers.markSynthetic(event)
        postQueue.async {
            event.postToPid(pid)
        }
    }

    private static func resolveTargetPID(from event: CGEvent) -> pid_t {
        let fromEvent = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
        if fromEvent > 1 {
            return fromEvent
        }
        // annotated tap 偶发拿不到 PID 时，退到前台应用（仍走 postToPid，不拽全局指针）
        if let front = NSWorkspace.shared.frontmostApplication?.processIdentifier, front > 1 {
            return front
        }
        return 0
    }
}
