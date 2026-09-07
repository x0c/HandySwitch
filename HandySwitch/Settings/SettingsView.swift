import SwiftUI

struct SettingsView: View {
    @Bindable private var launchAtLogin = LaunchAtLoginManager.shared
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case launch
        case openLogin
        case checkUpdates
        case quit
    }

    var body: some View {
        Form {
            Section(String(localized: "settings.status")) {
                Text(String(localized: "settings.running"))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(String(localized: "settings.general")) {
                Toggle(String(localized: "settings.launchAtLogin"), isOn: launchBinding)
                    .focused($focused, equals: .launch)
                    .focusEffectDisabled()

                Text(String(localized: "settings.launchAtLogin.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if launchAtLogin.requiresApproval {
                    Text(String(localized: "settings.launchAtLogin.needsApproval"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Button(String(localized: "settings.launchAtLogin.openLoginItems")) {
                        launchAtLogin.openSystemSettings()
                    }
                    .focused($focused, equals: .openLogin)
                    .focusEffectDisabled()
                }

                if let message = launchAtLogin.lastErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button(String(localized: "menu.checkForUpdates")) {
                    AppDelegate.shared?.checkForUpdates()
                }
                .focused($focused, equals: .checkUpdates)
                .focusEffectDisabled()

                Button(String(localized: "menu.quit")) {
                    AppDelegate.shared?.requestTermination()
                }
                .focused($focused, equals: .quit)
                .focusEffectDisabled()
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 300)
        .focusEffectDisabled()
        .onAppear {
            launchAtLogin.refresh()
        }
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        )
    }
}
