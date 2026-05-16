import Foundation
import ServiceManagement

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let retentionDays = "retentionDays"
        static let maxItems = "maxItems"
    }

    private let defaults: UserDefaults
    private var isApplyingStoredValues = false

    @Published var launchAtLogin: Bool {
        didSet {
            guard !isApplyingStoredValues else { return }
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLoginController.setEnabled(launchAtLogin)
        }
    }

    @Published var retentionDays: Int {
        didSet {
            let normalized = max(1, min(retentionDays, 3650))
            guard retentionDays == normalized else {
                retentionDays = normalized
                return
            }
            guard !isApplyingStoredValues else { return }
            defaults.set(retentionDays, forKey: Keys.retentionDays)
            ClipboardMonitor.shared.applySettings()
        }
    }

    @Published var maxItems: Int {
        didSet {
            let normalized = max(1, min(maxItems, 5000))
            guard maxItems == normalized else {
                maxItems = normalized
                return
            }
            guard !isApplyingStoredValues else { return }
            defaults.set(maxItems, forKey: Keys.maxItems)
            ClipboardMonitor.shared.applySettings()
        }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.launchAtLogin: true,
            Keys.retentionDays: 30,
            Keys.maxItems: 200
        ])

        isApplyingStoredValues = true
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        retentionDays = defaults.integer(forKey: Keys.retentionDays)
        maxItems = defaults.integer(forKey: Keys.maxItems)
        isApplyingStoredValues = false
    }
}

enum LaunchAtLoginController {
    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }

        do {
            let service = SMAppService.mainApp
            switch (enabled, service.status) {
            case (true, .enabled), (false, .notRegistered):
                return
            case (true, _):
                try service.register()
            case (false, _):
                try service.unregister()
            }
        } catch {
            NSLog("Failed to update launch at login: \(error.localizedDescription)")
        }
    }
}