import Foundation
import Observation

@MainActor
@Observable
final class AppPreferences {
    static let shared = AppPreferences()

    private enum Key {
        static let reverseMouseScroll = "reverseMouseScrollEnabled"
        static let smoothMouseScroll = "smoothMouseScrollEnabled"
    }

    private let defaults = UserDefaults.standard

    private(set) var reverseMouseScrollEnabled: Bool
    private(set) var smoothMouseScrollEnabled: Bool

    /// 动态高度浮层仍用宽度；高度由内容几何回调决定。
    static let panelSize = CGSize(width: 320, height: 296)
    static let panelCornerRadius: CGFloat = 20

    private init() {
        // 图标即主入口：清掉历史显隐偏好，不再提供隐藏能力。
        defaults.removeObject(forKey: "menuBarIconVisible")
        reverseMouseScrollEnabled = defaults.bool(forKey: Key.reverseMouseScroll)
        smoothMouseScrollEnabled = defaults.bool(forKey: Key.smoothMouseScroll)
    }

    func setReverseMouseScrollEnabled(_ enabled: Bool) {
        reverseMouseScrollEnabled = enabled
        defaults.set(enabled, forKey: Key.reverseMouseScroll)
    }

    func setSmoothMouseScrollEnabled(_ enabled: Bool) {
        smoothMouseScrollEnabled = enabled
        defaults.set(enabled, forKey: Key.smoothMouseScroll)
    }
}
