import Foundation
import AppKit
import ServiceManagement

extension Notification.Name {
    static let openHotkeyChanged = Notification.Name("openHotkeyChanged")
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let retentionDays = "retentionDays"
        static let maxItems = "maxItems"
        static let closeOnCopy = "closeOnCopy"
        static let openHotkey = "openHotkeyData"
        static let pinHotkey = "pinHotkeyData"
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

    @Published var closeOnCopy: Bool {
        didSet {
            guard !isApplyingStoredValues else { return }
            defaults.set(closeOnCopy, forKey: Keys.closeOnCopy)
        }
    }

    @Published var openHotkey: KeyCombo? {
        didSet {
            guard !isApplyingStoredValues else { return }
            store(openHotkey, forKey: Keys.openHotkey)
            NotificationCenter.default.post(name: .openHotkeyChanged, object: nil)
        }
    }

    @Published var pinHotkey: KeyCombo? {
        didSet {
            guard !isApplyingStoredValues else { return }
            store(pinHotkey, forKey: Keys.pinHotkey)
        }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.launchAtLogin: true,
            Keys.retentionDays: 30,
            Keys.maxItems: 200,
            Keys.closeOnCopy: false
        ])

        isApplyingStoredValues = true
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        retentionDays = defaults.integer(forKey: Keys.retentionDays)
        maxItems = defaults.integer(forKey: Keys.maxItems)
        closeOnCopy = defaults.bool(forKey: Keys.closeOnCopy)
        openHotkey = AppSettings.loadCombo(from: defaults, key: Keys.openHotkey,
                                           default: KeyCombo(keyCode: 9, modifiers: [.command, .shift]))
        pinHotkey = AppSettings.loadCombo(from: defaults, key: Keys.pinHotkey,
                                          default: KeyCombo(keyCode: 35, modifiers: [.command]))
        isApplyingStoredValues = false
    }

    private func store(_ combo: KeyCombo?, forKey key: String) {
        if let combo, let data = try? JSONEncoder().encode(combo) {
            defaults.set(data, forKey: key)
        } else {
            defaults.set(Data(), forKey: key)
        }
    }

    private static func loadCombo(from defaults: UserDefaults, key: String, default def: KeyCombo?) -> KeyCombo? {
        guard let data = defaults.data(forKey: key) else { return def }
        if data.isEmpty { return nil }
        return try? JSONDecoder().decode(KeyCombo.self, from: data)
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
