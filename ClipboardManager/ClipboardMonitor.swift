import SwiftUI
import AppKit

enum ClipboardItemType {
    case text, image
}

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let type: ClipboardItemType
    let text: String?
    let image: NSImage?
    let date: Date
    var isPinned: Bool = false

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    var preview: String {
        switch type {
        case .text:
            return text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case .image:
            if let size = image?.size {
                return "Image • \(Int(size.width))×\(Int(size.height)) px"
            }
            return "Image"
        }
    }

    var timeAgo: String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "Now" }
        if diff < 3600 { return "\(Int(diff/60)) min ago" }
        if diff < 86400 { return "\(Int(diff/3600)) hrs ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    @Published var items: [ClipboardItem] = []
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let image = NSImage(pasteboard: pasteboard) {
            let item = ClipboardItem(type: .image, text: nil, image: image, date: Date())
            addItem(item)
            return
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            if let last = items.first(where: { !$0.isPinned }), last.text == text { return }
            let item = ClipboardItem(type: .text, text: text, image: nil, date: Date())
            addItem(item)
        }
    }

    private func addItem(_ item: ClipboardItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var unpinned = self.items.filter { !$0.isPinned }
            let pinned = self.items.filter { $0.isPinned }
            if unpinned.count >= 195 {
                unpinned = Array(unpinned.prefix(195))
            }
            self.items = [item] + unpinned + pinned
        }
    }

    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.type {
        case .text:
            if let text = item.text {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let image = item.image {
                pasteboard.writeObjects([image])
            }
        }
        lastChangeCount = pasteboard.changeCount
    }

    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }

    func togglePin(_ item: ClipboardItem) {
        if let idx = items.firstIndex(of: item) {
            items[idx].isPinned.toggle()
        }
    }

    func clearAll() {
        items.removeAll { !$0.isPinned }
    }
}
