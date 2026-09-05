import ApplicationServices
import AppKit
import Foundation

enum AccessibilityPermission {
    private static let trustedCheckOptionPromptKey = "AXTrustedCheckOptionPrompt"

    nonisolated static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @MainActor
    @discardableResult
    static func requestTrust(prompt: Bool) -> Bool {
        guard prompt else {
            return AXIsProcessTrusted()
        }
        let options = [trustedCheckOptionPromptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @MainActor
    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
