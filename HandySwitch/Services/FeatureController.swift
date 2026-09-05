import Foundation
import Observation

/// 开关编排：持久化 + 权限失败回滚。防睡限时由 PreventSleepService 负责。
@MainActor
@Observable
final class FeatureController {
    static let shared = FeatureController()

    private let preferences = AppPreferences.shared
    private let preventSleep = PreventSleepService()
    private let mouseScroll = MouseScrollService.shared
    private let cleanMode = CleanModeService()
    private let darkMode = DarkModeService()

    private(set) var isCleanModeActive = false
    private(set) var isDarkModeEnabled = false
    private(set) var isPreventSleepEnabled = false
    private(set) var awakeDurationMinutes = PreventSleepSchedule.defaultMinutes
    private(set) var awakeDeadline: Date?
    private(set) var isReverseMouseScrollEnabled = false
    private(set) var isSmoothMouseScrollEnabled = false
    private(set) var needsAccessibilityHelp = false
    private(set) var needsAutomationHelp = false

    private init() {
        preventSleep.onExpired = { [weak self] in
            guard let self else { return }
            self.syncPreventSleepFromService()
        }
        cleanMode.onEnded = { [weak self] in
            guard let self else { return }
            self.isCleanModeActive = false
            self.needsAccessibilityHelp = false
        }
        darkMode.onStatusChange = { [weak self] in
            self?.syncDarkModeFromService()
        }
        syncPreventSleepFromService()
        syncDarkModeFromService()
    }

    func startPersistedFeatures() {
        refreshDarkModeFromSystem()
        preventSleep.restorePersistedState()
        syncPreventSleepFromService()
        applyMouseScrollFromPreferences()
    }

    func refreshDarkModeFromSystem() {
        darkMode.refreshFromSystem()
        syncDarkModeFromService()
    }

    func prepareForTermination() {
        cleanMode.stop()
        mouseScroll.stopAll()
        preventSleep.endForTermination()
        isCleanModeActive = false
        isReverseMouseScrollEnabled = false
        isSmoothMouseScrollEnabled = false
        syncPreventSleepFromService()
    }

    func setCleanModeActive(_ active: Bool) {
        if active {
            let ok = cleanMode.start()
            isCleanModeActive = ok
            needsAccessibilityHelp = !ok
        } else {
            cleanMode.stop()
            isCleanModeActive = false
        }
    }

    func setDarkModeEnabled(_ enabled: Bool) {
        darkMode.setEnabled(enabled)
        syncDarkModeFromService()
    }

    func setPreventSleepEnabled(_ enabled: Bool) {
        preventSleep.setEnabled(enabled)
        syncPreventSleepFromService()
    }

    func setAwakeDuration(minutes: Int) {
        preventSleep.setAwakeDuration(minutes: minutes)
        syncPreventSleepFromService()
    }

    /// 点预置时长：选用该时长并开启防睡。
    func selectAwakePreset(minutes: Int) {
        preventSleep.setAwakeDuration(minutes: minutes)
        if !preventSleep.isEnabled {
            preventSleep.setEnabled(true)
        }
        syncPreventSleepFromService()
    }

    func setReverseMouseScrollEnabled(_ enabled: Bool) {
        guard AccessibilityPermission.isTrusted() || !enabled else {
            AccessibilityPermission.requestTrust(prompt: true)
            needsAccessibilityHelp = true
            return
        }
        let ok = mouseScroll.setReverseEnabled(enabled)
        isReverseMouseScrollEnabled = mouseScroll.isReverseEnabled
        if enabled, !ok {
            needsAccessibilityHelp = true
            preferences.setReverseMouseScrollEnabled(false)
            isReverseMouseScrollEnabled = false
        } else {
            preferences.setReverseMouseScrollEnabled(mouseScroll.isReverseEnabled)
            if ok {
                needsAccessibilityHelp = false
            }
        }
    }

    func setSmoothMouseScrollEnabled(_ enabled: Bool) {
        guard AccessibilityPermission.isTrusted() || !enabled else {
            AccessibilityPermission.requestTrust(prompt: true)
            needsAccessibilityHelp = true
            return
        }
        let ok = mouseScroll.setSmoothEnabled(enabled)
        isSmoothMouseScrollEnabled = mouseScroll.isSmoothEnabled
        if enabled, !ok {
            needsAccessibilityHelp = true
            preferences.setSmoothMouseScrollEnabled(false)
            isSmoothMouseScrollEnabled = false
        } else {
            preferences.setSmoothMouseScrollEnabled(mouseScroll.isSmoothEnabled)
            if ok {
                needsAccessibilityHelp = false
            }
        }
    }

    private func syncPreventSleepFromService() {
        isPreventSleepEnabled = preventSleep.isEnabled
        awakeDurationMinutes = preventSleep.awakeDurationMinutes
        awakeDeadline = preventSleep.awakeDeadline
    }

    private func syncDarkModeFromService() {
        isDarkModeEnabled = darkMode.isDarkMode
        needsAutomationHelp = darkMode.needsAutomationHelp
    }

    private func applyMouseScrollFromPreferences() {
        let wantReverse = preferences.reverseMouseScrollEnabled
        let wantSmooth = preferences.smoothMouseScrollEnabled
        guard wantReverse || wantSmooth else { return }

        guard AccessibilityPermission.isTrusted() else {
            needsAccessibilityHelp = true
            return
        }

        if wantReverse {
            let ok = mouseScroll.setReverseEnabled(true)
            isReverseMouseScrollEnabled = mouseScroll.isReverseEnabled
            if !ok {
                preferences.setReverseMouseScrollEnabled(false)
                needsAccessibilityHelp = true
            }
        }
        if wantSmooth {
            let ok = mouseScroll.setSmoothEnabled(true)
            isSmoothMouseScrollEnabled = mouseScroll.isSmoothEnabled
            if !ok {
                preferences.setSmoothMouseScrollEnabled(false)
                needsAccessibilityHelp = true
            }
        }
    }
}
