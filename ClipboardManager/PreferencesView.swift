import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var settings = AppSettings.shared

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        formatter.minimum = 1
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 14) {
                settingRow(
                    title: "Launch at Login",
                    description: "Start Clipboard Manager automatically when your Mac starts.") {
                        Toggle("", isOn: $settings.launchAtLogin)
                            .labelsHidden()
                    }

                Divider()

                settingRow(
                    title: "Open Shortcut",
                    description: "Global hotkey to show Clipboard Manager from anywhere.") {
                        shortcutControl(binding: $settings.openHotkey)
                    }

                Divider()

                settingRow(
                    title: "Pin / Unpin Shortcut",
                    description: "Pin or unpin the selected item while the window is open.") {
                        shortcutControl(binding: $settings.pinHotkey)
                    }

                Divider()

                settingRow(
                    title: "Close After Copy",
                    description: "Automatically close the window right after you copy an item.") {
                        Toggle("", isOn: $settings.closeOnCopy)
                            .labelsHidden()
                    }

                Divider()

                settingRow(
                    title: "Retention Period",
                    description: "Remove unpinned history items older than this many days.") {
                        numberField(value: $settings.retentionDays, range: 1...3650, unit: "days")
                    }

                Divider()

                settingRow(
                    title: "Maximum History Items",
                    description: "Limit how many unpinned records are stored at once.") {
                        numberField(value: $settings.maxItems, range: 1...5000, unit: "items")
                    }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )

            Spacer()
        }
        .padding(24)
        .frame(width: 480, height: 520)
    }

    @ViewBuilder
    private func settingRow<Control: View>(title: String, description: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            control()
        }
    }

    /// An editable number field paired with a stepper so the value can be typed
    /// or adjusted with the arrows.
    @ViewBuilder
    private func numberField(value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack(spacing: 6) {
            TextField("", value: value, formatter: Self.integerFormatter)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
            Text(unit)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Stepper("", value: value, in: range)
                .labelsHidden()
        }
    }

    /// A shortcut recorder with a button to clear (disable) the shortcut.
    @ViewBuilder
    private func shortcutControl(binding: Binding<KeyCombo?>) -> some View {
        HStack(spacing: 6) {
            ShortcutRecorder(combo: binding)
                .frame(width: 120, height: 24)
            Button(action: { binding.wrappedValue = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(binding.wrappedValue == nil)
            .opacity(binding.wrappedValue == nil ? 0.3 : 1)
            .help("Clear shortcut")
        }
    }
}
