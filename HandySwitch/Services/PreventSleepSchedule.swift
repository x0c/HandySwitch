import Foundation

/// 防睡时长的产品边界与截止时间计算。
struct PreventSleepSchedule {
    static let defaultMinutes = 300
    static let minimumMinutes = 1
    static let maximumMinutes = 10_080

    static func validatedMinutes(_ minutes: Int) -> Int {
        min(max(minutes, minimumMinutes), maximumMinutes)
    }

    static func deadline(now: Date, minutes: Int) -> Date {
        now.addingTimeInterval(TimeInterval(validatedMinutes(minutes) * 60))
    }
}
