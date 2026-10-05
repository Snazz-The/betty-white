import Foundation
import Observation
import ServiceManagement

/// Wraps SMAppService so the app can start when you log in.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    private(set) var needsApproval = SMAppService.mainApp.status == .requiresApproval
    var lastError: String?

    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
