import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var settings = AppSettings.shared

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
                    title: "Retention Period",
                    description: "Remove unpinned history items older than this many days.") {
                        Stepper(value: $settings.retentionDays, in: 1...3650) {
                            Text("\(settings.retentionDays) days")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(width: 160, alignment: .trailing)
                    }

                Divider()

                settingRow(
                    title: "Maximum History Items",
                    description: "Limit how many unpinned records are stored at once.") {
                        Stepper(value: $settings.maxItems, in: 1...5000) {
                            Text("\(settings.maxItems) items")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(width: 160, alignment: .trailing)
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
        .frame(width: 460, height: 240)
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
}