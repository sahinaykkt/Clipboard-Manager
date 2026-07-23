import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var monitor = ClipboardMonitor.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var searchText = ""
    @State private var selectedFilter: FilterType = .all
    @State private var selectedID: UUID? = nil
    @State private var copiedID: UUID? = nil
    @State private var followSelection = false

    enum FilterType: String, CaseIterable {
        case all = "All"
        case text = "Text"
        case image = "Image"
        case pinned = "Pinned"
    }

    private var selectedItem: ClipboardItem? {
        filtered.first { $0.id == selectedID }
    }

    var filtered: [ClipboardItem] {
        monitor.items.filter { item in
            let matchesFilter: Bool = {
                switch selectedFilter {
                case .all: return true
                case .text: return item.type == .text
                case .image: return item.type == .image
                case .pinned: return item.isPinned
                }
            }()
            let matchesSearch: Bool = {
                if searchText.isEmpty { return true }
                switch item.type {
                case .text: return item.text?.localizedCaseInsensitiveContains(searchText) ?? false
                case .image: return "image".contains(searchText.lowercased())
                }
            }()
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "clipboard.fill")
                    .foregroundColor(.accentColor)
                Text("Clipboard Manager")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(monitor.items.count) items")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Button(action: { monitor.clearAll() }) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear all except pinned")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            HStack(spacing: 4) {
                ForEach(FilterType.allCases, id: \.self) { f in
                    Button(action: { selectedFilter = f }) {
                        Text(f.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(selectedFilter == f ? Color.accentColor : Color.clear)
                            .foregroundColor(selectedFilter == f ? .white : .secondary)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "Nothing copied yet" : "No results found")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filtered) { item in
                                ClipboardRow(
                                    item: item,
                                    selectedID: $selectedID,
                                    copiedID: $copiedID,
                                    isCurrentClipboard: item.id == monitor.lastCopiedID,
                                    onCopy: { copyItem(item) },
                                    onPin: { monitor.togglePin(item) },
                                    onDelete: { monitor.deleteItem(item) }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: selectedID) { id in
                        defer { followSelection = false }
                        guard followSelection, let id else { return }
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }

            Divider()

            HStack {
                Button(action: openPreferences) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Preferences")

                Spacer()

                Button("Quit") { NSApp.terminate(nil) }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 360, minHeight: 480)
        .background(KeyCaptureView { handleKey($0) })
        .onAppear {
            if selectedID == nil { selectedID = filtered.first?.id }
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        if let pin = settings.pinHotkey, pin.matches(event) {
            if let item = selectedItem { monitor.togglePin(item) }
            return true
        }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

        switch event.keyCode {
        case 125:
            moveSelection(by: 1)
            return true
        case 126:
            moveSelection(by: -1)
            return true
        case 36, 76:
            if let item = selectedItem { copyItem(item) }
            return true
        case 51:
            if modifiers.contains(.command) || searchText.isEmpty {
                deleteSelected()
                return true
            }
            return false
        case 117:
            deleteSelected()
            return true
        default:
            return false
        }
    }

    private func deleteSelected() {
        guard let item = selectedItem else { return }
        selectNeighbour(of: item)
        monitor.deleteItem(item)
    }

    private func moveSelection(by delta: Int) {
        let list = filtered
        guard !list.isEmpty else { return }
        followSelection = true
        guard let id = selectedID, let index = list.firstIndex(where: { $0.id == id }) else {
            selectedID = delta > 0 ? list.first?.id : list.last?.id
            return
        }
        let next = min(max(index + delta, 0), list.count - 1)
        selectedID = list[next].id
    }

    private func selectNeighbour(of item: ClipboardItem) {
        let list = filtered
        guard let index = list.firstIndex(where: { $0.id == item.id }) else { return }
        followSelection = true
        if index + 1 < list.count {
            selectedID = list[index + 1].id
        } else if index - 1 >= 0 {
            selectedID = list[index - 1].id
        } else {
            selectedID = nil
        }
    }

    private func openPreferences() {
        DispatchQueue.main.async {
            AppDelegate.shared?.showPreferencesWindow()
        }
    }

    private func copyItem(_ item: ClipboardItem) {
        selectedID = item.id
        monitor.copyToClipboard(item)
        withAnimation { copiedID = item.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedID == item.id { copiedID = nil }
        }
        if settings.closeOnCopy {
            AppDelegate.shared?.dismissPopover()
        }
    }

    struct ClipboardRow: View {
        let item: ClipboardItem
        @Binding var selectedID: UUID?
        @Binding var copiedID: UUID?
        let isCurrentClipboard: Bool
        let onCopy: () -> Void
        let onPin: () -> Void
        let onDelete: () -> Void

        @State private var isHovered = false

        var isSelected: Bool { selectedID == item.id }
        var isCopied: Bool { copiedID == item.id }

        var body: some View {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(item.type == .image ? Color.purple.opacity(0.12) : Color.blue.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: item.type == .image ? "photo" : "doc.text")
                            .font(.system(size: 14))
                            .foregroundColor(item.type == .image ? .purple : .blue)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        if item.type == .image, let img = item.image {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 60)
                                .cornerRadius(4)
                        } else {
                            Text(item.preview)
                                .font(.system(size: 12))
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }
                        Text(item.timeAgo)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if item.isPinned && !isHovered && !isSelected {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedID = item.id
                    onCopy()
                }
                .help("Click to copy to clipboard")

                if isHovered || isCopied || isSelected {
                    HStack(spacing: 6) {
                        if isCopied {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                        } else {
                            Button(action: onCopy) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .help("Copy")

                            Button(action: onPin) {
                                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(item.isPinned ? .orange : .secondary)
                            .help(item.isPinned ? "Unpin" : "Pin")

                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red.opacity(0.7))
                            .help("Delete")
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(rowBackgroundColor)
            )
            .overlay(alignment: .leading) {
                if isCurrentClipboard {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.green)
                        .frame(width: 3)
                        .padding(.vertical, 6)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
                if hovering { selectedID = item.id }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .animation(.easeInOut(duration: 0.2), value: isCopied)
            .animation(.easeInOut(duration: 0.2), value: isCurrentClipboard)
        }

        private var rowBackgroundColor: Color {
            if isSelected {
                return Color(NSColor.selectedContentBackgroundColor).opacity(0.22)
            }
            if isHovered {
                return Color(NSColor.selectedContentBackgroundColor).opacity(0.15)
            }
            return .clear
        }
    }
}

struct KeyCaptureView: NSViewRepresentable {
    let handler: (NSEvent) -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.handler = handler
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let coordinator = context.coordinator
            guard let window = coordinator.view?.window, window.isKeyWindow else { return event }
            return coordinator.handler(event) ? nil : event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.handler = handler
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
        }
        coordinator.monitor = nil
    }

    final class Coordinator {
        weak var view: NSView?
        var monitor: Any?
        var handler: (NSEvent) -> Bool = { _ in false }
    }
}
