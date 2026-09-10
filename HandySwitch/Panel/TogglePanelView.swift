import SwiftUI

struct TogglePanelView: View {
    @Bindable var model: FeatureController
    var onHeightChange: (CGFloat) -> Void = { _ in }

    private static let awakePresets = [60, 180, 300, 480]
    private static let rowHeight: CGFloat = 44
    private static let iconColumn: CGFloat = 24
    private static let rowSpacing: CGFloat = 12

    private static let cardCornerRadius: CGFloat = 12

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                HStack {
                    Text("HandySwitch").font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

                row("panel.cleanMode", icon: "sparkles", isOn: Binding(
                    get: { model.isCleanModeActive }, set: { model.setCleanModeActive($0) }))
                separator
                row("panel.darkMode", icon: "moon.fill", isOn: Binding(
                    get: { model.isDarkModeEnabled }, set: { model.setDarkModeEnabled($0) }))
                separator
                preventSleepSection
                separator
                row("panel.reverseMouseScroll", icon: "arrow.up.arrow.down", isOn: Binding(
                    get: { model.isReverseMouseScrollEnabled }, set: { model.setReverseMouseScrollEnabled($0) }))
                separator
                row("panel.smoothMouseScroll", icon: "water.waves", isOn: Binding(
                    get: { model.isSmoothMouseScrollEnabled }, set: { model.setSmoothMouseScrollEnabled($0) }))
            }
            .background(cardFill, in: RoundedRectangle(cornerRadius: Self.cardCornerRadius))

            if model.needsAccessibilityHelp {
                helpBanner(
                    icon: "lock.shield",
                    message: "panel.accessibilityNeeded",
                    actionTitle: "panel.openAccessibility",
                    action: AccessibilityPermission.openSystemSettings
                )
            }

            if model.needsAutomationHelp {
                if model.automationAccessDenied {
                    helpBanner(
                        icon: "gearshape.2",
                        message: "panel.automationDenied",
                        actionTitle: "panel.openAutomation",
                        action: AutomationPermission.openSystemSettings
                    )
                } else {
                    helpBanner(
                        icon: "gearshape.2",
                        message: "panel.automationNeeded",
                        actionTitle: "panel.retryAutomation",
                        action: { model.retryAutomationAccess() }
                    )
                }
            }
        }
        .padding(8)
        .frame(width: AppPreferences.panelSize.width)
        .fixedSize(horizontal: false, vertical: true)
        .focusEffectDisabled()
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
    }

    private var cardFill: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    private var separator: some View {
        Divider().padding(.leading, 12 + Self.iconColumn + Self.rowSpacing).padding(.trailing, 12)
    }

    private var preventSleepSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Self.rowSpacing) {
                symbol("cup.and.saucer", active: model.isPreventSleepEnabled)
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "panel.preventSleep"))
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if model.isPreventSleepEnabled {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(durationLabel(at: context.date))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 8)
                switchControl("panel.preventSleep", isOn: Binding(
                    get: { model.isPreventSleepEnabled }, set: { model.setPreventSleepEnabled($0) }))
            }
            .padding(.horizontal, 12)
            .frame(height: Self.rowHeight)

            HStack(spacing: 6) {
                ForEach(Self.awakePresets, id: \.self) { value in
                    presetChip(minutes: value)
                }
            }
            .padding(.leading, 12 + Self.iconColumn + Self.rowSpacing)
            .padding(.trailing, 12)
            .padding(.top, 2)
            .padding(.bottom, 10)
        }
    }

    private func presetChip(minutes: Int) -> some View {
        let selected = model.awakeDurationMinutes == minutes
        let title = String(format: String(localized: "awake.hoursPreset"), minutes / 60)
        return Button {
            model.selectAwakePreset(minutes: minutes)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? Color.primary.opacity(0.14) : Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(selected ? Color.primary.opacity(0.22) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func helpBanner(
        icon: String,
        message: String.LocalizationValue,
        actionTitle: String.LocalizationValue,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(String(localized: message))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(String(localized: actionTitle), action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(12)
    }

    private func symbol(_ name: String, active: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(active ? Color.accentColor : Color.secondary)
            .frame(width: Self.iconColumn, height: Self.iconColumn)
            .accessibilityHidden(true)
    }

    private func row(_ key: String.LocalizationValue, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Self.rowSpacing) {
            symbol(icon, active: isOn.wrappedValue)
            Text(String(localized: key))
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            switchControl(key, isOn: isOn)
        }
        .padding(.horizontal, 12)
        .frame(height: Self.rowHeight)
    }

    private func switchControl(_ key: String.LocalizationValue, isOn: Binding<Bool>) -> some View {
        Toggle(String(localized: key), isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .frame(width: 32)
            .focusEffectDisabled()
    }

    private func durationLabel(at date: Date) -> String {
        let seconds = model.awakeDeadline.map { max(0, $0.timeIntervalSince(date)) }
        let total = seconds.map { Int(ceil($0 / 60)) } ?? model.awakeDurationMinutes
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = total >= 60 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        let value = formatter.string(from: TimeInterval(total * 60)) ?? ""
        return String(format: String(localized: "awake.remaining"), value)
    }
}
