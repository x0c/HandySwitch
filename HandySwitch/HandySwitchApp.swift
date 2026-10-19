import AppKit
import Foundation
import MacKitLifecycle
import SwiftUI

@main
struct HandySwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        AutofillHeuristicGuard.install()
    }

    var body: some Scene {
        // AppDelegate owns the status item; Settings opens only on demand.
        Settings {
            SettingsView()
        }
        .commands {
            SettingsPresenterCommands()
        }
    }
}
