# Clipboard Manager

A lightweight clipboard history manager for macOS. It automatically saves copied text and images, keeps them across app relaunches and system restarts, and lets you reuse them directly from the menu bar.

App Store: [Clipboard Manager - Simple](https://apps.apple.com/tr/app/clipboard-manager-simple/id6762162041?l=tr&mt=12)

## Features

- Persistent clipboard history for text and images
- Single-click copy from the menu bar list
- Global shortcut to open the window from anywhere (default `⇧⌘V`)
- Full keyboard navigation: arrows to move, `Return` to copy, `Delete` to remove
- Pin important items to keep them available, with a shortcut (default `⌘P`)
- Search and filter history by type (All / Text / Image / Pinned)
- The item currently on the clipboard is marked in the list
- Optional "close after copy" behavior
- Launch at login enabled by default after install
- Preferences for startup behavior, shortcuts, retention days, and maximum history size
- Right-click menu bar context menu with Preferences and Quit
- Local-only storage with configurable history limits

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15 or later

## Build

1. Open the project:
   ```
   open ClipboardManager.xcodeproj
   ```
2. Select your team under **Signing & Capabilities**.
3. Press **Cmd+R** to build and run.

## Usage

- Left-click the menu bar icon, or press the global shortcut (`⇧⌘V` by default), to open clipboard history.
- Click any item once to copy it back to the clipboard.
- Hover an item to select it; the pin, copy, and delete buttons appear on the selected row.
- Right-click the menu bar icon to open Preferences or quit the app.
- Use Preferences to change launch at login, shortcuts, close-after-copy, retention period, and maximum saved items.

### Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `⇧⌘V` | Open Clipboard Manager (global, configurable) |
| `↑` / `↓` | Move selection |
| `Return` | Copy the selected item |
| `⌘P` | Pin / unpin the selected item (configurable) |
| `Delete` | Delete the selected item (`⌘Delete` while typing in search) |
| `Esc` | Cancel shortcut recording in Preferences |

## App Store Submission Checklist

- Verify bundle identifier and signing team in Xcode
- Replace placeholder icons in `Assets.xcassets/AppIcon.appiconset`
- Archive a Release build and upload to App Store Connect
- Fill in pricing, availability, support URL, and privacy policy URL
- Add screenshots matching App Store size requirements
- Submit with the review notes in `docs/AppStoreRelease.md`

## Project Structure

```
ClipboardManager/
├── ClipboardManager.xcodeproj/
└── ClipboardManager/
    ├── AppSettings.swift           # Persistent settings and launch-at-login handling
    ├── ClipboardManagerApp.swift   # App entry point, AppDelegate, menu bar setup
    ├── ClipboardMonitor.swift      # Pasteboard monitor and persistent history storage
    ├── ContentView.swift           # Main UI
    ├── PreferencesView.swift       # Preferences window UI
    ├── ClipboardManager.entitlements
    └── Info.plist
```

## Privacy

Clipboard Manager stores all clipboard history locally on the device. No data is uploaded, shared, or transmitted to any server. See `docs/PrivacyPolicy.md` for the full policy.
