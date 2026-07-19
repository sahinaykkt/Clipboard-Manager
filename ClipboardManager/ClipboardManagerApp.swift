import SwiftUI
import AppKit
import Carbon.HIToolbox

// MARK: - KeyCombo

/// A keyboard shortcut (virtual key code + modifier flags) that is Codable so it
/// can be stored in UserDefaults, and convertible to Carbon flags for global
/// hotkey registration.
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt16
    /// Raw value of the device-independent `NSEvent.ModifierFlags` subset.
    var modifierRawValue: UInt

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierRawValue = modifiers.intersection(KeyCombo.relevantFlags).rawValue
    }

    static let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierRawValue).intersection(KeyCombo.relevantFlags)
    }

    var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        if modifierFlags.contains(.command) { flags |= UInt32(cmdKey) }
        if modifierFlags.contains(.option) { flags |= UInt32(optionKey) }
        if modifierFlags.contains(.control) { flags |= UInt32(controlKey) }
        if modifierFlags.contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }

    /// Whether a live key-down event matches this combo (used for in-app shortcuts).
    func matches(_ event: NSEvent) -> Bool {
        event.keyCode == keyCode &&
        event.modifierFlags.intersection(KeyCombo.relevantFlags) == modifierFlags
    }

    var displayString: String {
        var result = ""
        if modifierFlags.contains(.control) { result += "⌃" }
        if modifierFlags.contains(.option) { result += "⌥" }
        if modifierFlags.contains(.shift) { result += "⇧" }
        if modifierFlags.contains(.command) { result += "⌘" }
        result += KeyCombo.keyName(for: keyCode)
        return result
    }

    static func keyName(for keyCode: UInt16) -> String {
        if let special = specialKeyNames[keyCode] { return special }
        let map: [UInt16: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
            34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
            12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
            16: "Y", 6: "Z",
            29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
            28: "8", 25: "9",
            27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";", 39: "'",
            43: ",", 47: ".", 44: "/", 50: "`"
        ]
        return map[keyCode] ?? "Key \(keyCode)"
    }

    private static let specialKeyNames: [UInt16: String] = [
        49: "Space", 36: "↩", 76: "⌤", 48: "⇥", 51: "⌫", 117: "⌦", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]
}

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}



class AppDelegate: NSObject, NSApplicationDelegate {
    /// SwiftUI's `@NSApplicationDelegateAdaptor` wraps this delegate, so
    /// `NSApp.delegate` is a `SwiftUI.AppDelegate` and casting it to our type
    /// fails. We keep an explicit reference so views can reach the real delegate.
    static weak var shared: AppDelegate?

    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var mainWindow: NSWindow?
    var preferencesWindow: NSWindow?
    private lazy var statusMenu: NSMenu = makeStatusMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)
        LaunchAtLoginController.setEnabled(AppSettings.shared.launchAtLogin)

        GlobalHotkeyManager.shared.onFire = { [weak self] in
            self?.togglePopover()
        }
        GlobalHotkeyManager.shared.register(AppSettings.shared.openHotkey)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reregisterGlobalHotkey),
            name: .openHotkeyChanged,
            object: nil
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "doc.on.doc.fill", accessibilityDescription: "Clipboard Manager")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
        self.popover = popover

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Clipboard Manager"
        window.contentView = NSHostingView(rootView: ContentView())
        window.isReleasedWhenClosed = false
        self.mainWindow = window

        ClipboardMonitor.shared.startMonitoring()
    }

    @objc func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseUp {
            popover?.performClose(nil)
            NSMenu.popUpContextMenu(statusMenu, with: event, for: sender)
            return
        }

        togglePopover()
    }

    @objc func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                if let button = statusItem?.button {
                    popover.contentViewController = NSHostingController(rootView: ContentView())
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                    // Activate so the popover window becomes key and its search
                    // field / keyboard navigation can receive events (needed when
                    // opened via the global hotkey rather than a click).
                    NSApp.activate(ignoringOtherApps: true)
                    popover.contentViewController?.view.window?.makeKey()
                }
            }
        }
    }

    /// Closes the popover if it is currently shown (used by "Close after copy").
    func dismissPopover() {
        DispatchQueue.main.async { [weak self] in
            self?.popover?.close()
        }
    }

    @objc private func reregisterGlobalHotkey() {
        GlobalHotkeyManager.shared.register(AppSettings.shared.openHotkey)
    }

    @objc func showPreferencesWindow() {
        popover?.performClose(nil)
        if preferencesWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Preferences"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PreferencesView())
            preferencesWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow?.center()
        preferencesWindow?.makeKeyAndOrderFront(nil)
        preferencesWindow?.orderFrontRegardless()
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    func showMainWindow() {
        mainWindow?.contentView = NSHostingView(rootView: ContentView())
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(showPreferencesWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApplication), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        return menu
    }
}

// MARK: - Global Hotkey (Carbon)

/// Registers a single system-wide hotkey using Carbon's `RegisterEventHotKey`,
/// which works inside the App Sandbox and does not require Accessibility access.
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    var onFire: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: 0x434C_4950 /* 'CLIP' */, id: 1)

    private init() {}

    /// Registers `combo` as the global hotkey, replacing any previous one.
    /// Passing `nil` simply unregisters (shortcut disabled).
    func register(_ combo: KeyCombo?) {
        unregister()
        guard let combo, combo.carbonModifiers != 0 else { return }
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode),
            combo.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
        } else {
            NSLog("Failed to register global hotkey (status \(status))")
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, let event else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                var firedID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &firedID
                )
                if firedID.id == manager.hotKeyID.id {
                    DispatchQueue.main.async { manager.onFire?() }
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }
}

// MARK: - Shortcut Recorder

/// A small control that records a keyboard shortcut when clicked. Bound to an
/// optional `KeyCombo`; used in Preferences for the global and pin shortcuts.
struct ShortcutRecorder: NSViewRepresentable {
    @Binding var combo: KeyCombo?

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.combo = combo
        view.onChange = { self.combo = $0 }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        if nsView.combo != combo { nsView.combo = combo }
        nsView.onChange = { self.combo = $0 }
    }
}

final class ShortcutRecorderNSView: NSView {
    var combo: KeyCombo? { didSet { needsDisplay = true } }
    var onChange: ((KeyCombo?) -> Void)?

    private var isRecording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize { NSSize(width: 120, height: 24) }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording()
        } else {
            isRecording = true
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        if event.keyCode == 53 { // Escape cancels recording
            stopRecording()
            return
        }

        let modifiers = event.modifierFlags.intersection(KeyCombo.relevantFlags)
        guard !modifiers.isEmpty else {
            // Require at least one modifier so shortcuts are safe globally.
            NSSound.beep()
            return
        }

        let newCombo = KeyCombo(keyCode: event.keyCode, modifiers: modifiers)
        combo = newCombo
        onChange?(newCombo)
        stopRecording()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    private func stopRecording() {
        isRecording = false
        window?.makeFirstResponder(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)

        (isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.15)
            : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text: String
        let color: NSColor
        if isRecording {
            text = "Type shortcut…"
            color = .controlAccentColor
        } else if let combo {
            text = combo.displayString
            color = .labelColor
        } else {
            text = "Click to record"
            color = .secondaryLabelColor
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let size = attributed.size()
        attributed.draw(at: NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        ))
    }
}
