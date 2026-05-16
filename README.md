# Clipboard Manager

A lightweight clipboard history manager for macOS. It automatically saves copied text and images, keeps them across app relaunches and system restarts, and lets you reuse them directly from the menu bar.

App Store: [Clipboard Manager - Simple](https://apps.apple.com/tr/app/clipboard-manager-simple/id6762162041?l=tr&mt=12)

## Features

- Persistent clipboard history for text and images
- Single-click copy from the menu bar list
- Search and filter history by type
- Pin important items to keep them available
- Launch at login enabled by default after install
- Preferences for startup behavior, retention days, and maximum history size
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

- Left-click the menu bar icon to open clipboard history.
- Click any item once to copy it back to the clipboard.
- Right-click the menu bar icon to open Preferences or quit the app.
- Use Preferences to change launch at login, retention period, and maximum saved items.

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
