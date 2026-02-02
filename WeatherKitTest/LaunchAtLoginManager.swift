import SwiftUI
import ServiceManagement
import Combine

// MARK: - Launch at Login Manager
@available(macOS 13.0, *)
class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()
    
    @Published var isEnabled: Bool = false
    
    private init() {
        updateStatus()
    }
    
    func updateStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            updateStatus()
        } catch {
            print("Failed to \(isEnabled ? "unregister" : "register") launch at login: \(error.localizedDescription)")
        }
    }
    
    func enable() {
        guard !isEnabled else { return }
        toggle()
    }
    
    func disable() {
        guard isEnabled else { return }
        toggle()
    }
}
