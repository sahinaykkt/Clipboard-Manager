import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var monitor = ClipboardMonitor.shared
    @State private var searchText = ""
    @State private var selectedFilter: FilterType = .all
    @State private var selectedID: UUID? = nil
    @State private var copiedID: UUID? = nil
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case text = "Text"
        case image = "Image"
        case pinned = "Pinned"
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
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filtered) { item in
                            ClipboardRow(
                                item: item,
                                selectedID: $selectedID,
                                copiedID: $copiedID,
                                onCopy: { copyItem(item) },
                                onPin: { monitor.togglePin(item) },
                                onDelete: { monitor.deleteItem(item) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Divider()
            
            HStack {
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
    }

    private func copyItem(_ item: ClipboardItem) {
        selectedID = item.id
        monitor.copyToClipboard(item)
        withAnimation { copiedID = item.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedID == item.id { copiedID = nil }
        }
    }
    
    
    struct ClipboardRow: View {
        let item: ClipboardItem
        @Binding var selectedID: UUID?
        @Binding var copiedID: UUID?
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
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .animation(.easeInOut(duration: 0.2), value: isCopied)
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
