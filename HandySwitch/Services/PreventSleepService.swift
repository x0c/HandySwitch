import Foundation
import IOKit.pwr_mgt
import Observation
import OSLog

@MainActor
protocol PreventSleepAssertionManaging {
    func createAssertion(timeout: TimeInterval) -> IOPMAssertionID?
    func releaseAssertion(_ id: IOPMAssertionID)
}

@MainActor
private final class SystemPreventSleepAssertionManager: PreventSleepAssertionManaging {
    private static let logger = Logger(subsystem: "top.caozc.HandySwitch", category: "PreventSleep")

    func createAssertion(timeout: TimeInterval) -> IOPMAssertionID? {
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithDescription(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            "HandySwitch Prevent Sleep" as CFString,
            nil,
            "HandySwitch Prevent Sleep" as CFString,
            nil,
            timeout,
            kIOPMAssertionTimeoutActionTurnOff as CFString,
            &id
        )
        guard result == kIOReturnSuccess else {
            Self.logger.error("创建防睡眠断言失败 result=\(result)")
            return nil
        }
        return id
    }

    func releaseAssertion(_ id: IOPMAssertionID) {
        let result = IOPMAssertionRelease(id)
        if result != kIOReturnSuccess {
            Self.logger.error("释放防睡眠断言失败 result=\(result)")
        }
    }
}

/// 进程内电源断言：保存截止时间，开关到期后自动释放。
@MainActor
@Observable
final class PreventSleepService {
    private static let enabledKey = "preventSleepEnabled"
    private static let deadlineKey = "awakeDeadline"

    private let defaults: UserDefaults
    private let now: () -> Date
    private let assertionManager: PreventSleepAssertionManaging
    private var assertionID: IOPMAssertionID?
    private var expirationTask: Task<Void, Never>?

    private(set) var awakeDurationMinutes = PreventSleepSchedule.defaultMinutes
    private(set) var awakeDeadline: Date?
    private(set) var isEnabled = false
    var onExpired: (() -> Void)?

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        assertionManager: PreventSleepAssertionManaging = SystemPreventSleepAssertionManager()
    ) {
        self.defaults = defaults
        self.now = now
        self.assertionManager = assertionManager
        if let storedDeadline = defaults.object(forKey: Self.deadlineKey) as? Date {
            awakeDeadline = storedDeadline
        } else if let timestamp = defaults.object(forKey: Self.deadlineKey) as? Double {
            awakeDeadline = Date(timeIntervalSince1970: timestamp)
        }
    }

    func setAwakeDuration(minutes: Int) {
        awakeDurationMinutes = PreventSleepSchedule.validatedMinutes(minutes)
        guard isEnabled else { return }
        awakeDeadline = PreventSleepSchedule.deadline(now: now(), minutes: awakeDurationMinutes)
        persistDeadline()
        releaseAssertion()
        createAssertionIfNeeded()
        scheduleExpiration()
    }

    /// 启动时恢复保存的剩余时间；旧版本只有 enabled 时迁移为默认五小时。
    func restorePersistedState() {
        guard defaults.bool(forKey: Self.enabledKey) else {
            isEnabled = false
            return
        }

        if awakeDeadline == nil {
            awakeDeadline = PreventSleepSchedule.deadline(now: now(), minutes: awakeDurationMinutes)
            persistDeadline()
        }
        guard let deadline = awakeDeadline, deadline > now() else {
            expire()
            return
        }
        createAssertionIfNeeded()
        scheduleExpiration()
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            if isEnabled {
                checkExpiration()
                return
            }
            awakeDeadline = PreventSleepSchedule.deadline(now: now(), minutes: awakeDurationMinutes)
            persistDeadline()
            defaults.set(true, forKey: Self.enabledKey)
            createAssertionIfNeeded()
            scheduleExpiration()
        } else {
            end(clearSchedule: true)
        }
    }

    func begin() {
        if defaults.bool(forKey: Self.enabledKey) {
            restorePersistedState()
        } else {
            setEnabled(true)
        }
    }

    /// 退出时释放系统断言，但保留 enabled 与 deadline 供下次启动恢复。
    func endForTermination() {
        expirationTask?.cancel()
        expirationTask = nil
        releaseAssertion()
        isEnabled = false
    }

    func end() {
        end(clearSchedule: true)
    }

    /// 测试和定时器共用的到期检查入口。
    func checkExpiration() {
        guard let deadline = awakeDeadline else { return }
        if deadline <= now() {
            expire()
        } else if isEnabled {
            scheduleExpiration()
        }
    }

    private func createAssertionIfNeeded() {
        guard assertionID == nil else {
            isEnabled = true
            return
        }
        let timeout = max(1, (awakeDeadline ?? now()).timeIntervalSince(now()))
        guard let id = assertionManager.createAssertion(timeout: timeout) else {
            expire()
            return
        }
        assertionID = id
        isEnabled = true
    }

    private func releaseAssertion() {
        guard let id = assertionID else { return }
        assertionID = nil
        assertionManager.releaseAssertion(id)
    }

    private func end(clearSchedule: Bool) {
        expirationTask?.cancel()
        expirationTask = nil
        releaseAssertion()
        isEnabled = false
        defaults.set(false, forKey: Self.enabledKey)
        if clearSchedule {
            awakeDeadline = nil
            defaults.removeObject(forKey: Self.deadlineKey)
        }
    }

    private func expire() {
        expirationTask?.cancel()
        expirationTask = nil
        releaseAssertion()
        isEnabled = false
        awakeDeadline = nil
        defaults.set(false, forKey: Self.enabledKey)
        defaults.removeObject(forKey: Self.deadlineKey)
        onExpired?()
    }

    private func persistDeadline() {
        if let awakeDeadline {
            defaults.set(awakeDeadline.timeIntervalSince1970, forKey: Self.deadlineKey)
        } else {
            defaults.removeObject(forKey: Self.deadlineKey)
        }
    }

    private func scheduleExpiration() {
        expirationTask?.cancel()
        guard isEnabled, let deadline = awakeDeadline else { return }
        let interval = max(0.1, deadline.timeIntervalSince(now()))
        expirationTask = Task { [weak self] in
            let nanoseconds = UInt64(interval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            self?.checkExpiration()
        }
    }
}
