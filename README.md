# Clipboard Manager

A lightweight clipboard history manager for macOS. Automatically saves everything you copy — text and images — so you can find and reuse it from the menu bar.

## Features

- Clipboard history for text and images
- Menu bar access for instant retrieval
- Search and filter your history
- Pin important items to keep them at the top
- Double-click any item to copy it back to the clipboard
- Up to 200 items stored locally on device

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
    ├── ClipboardManagerApp.swift   # App entry point, AppDelegate, menu bar setup
    ├── ClipboardMonitor.swift      # Pasteboard monitor and data model
    ├── ContentView.swift           # Main UI
    ├── Assets.xcassets             # App icons and accent color
    ├── ClipboardManager.entitlements
    └── Info.plist
```

## Privacy

Clipboard Manager stores all data locally on the device. No data is uploaded, shared, or transmitted to any server. See `docs/PrivacyPolicy.md` for the full policy.
