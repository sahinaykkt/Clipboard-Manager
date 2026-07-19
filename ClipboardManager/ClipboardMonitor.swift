import SwiftUI
import AppKit

enum ClipboardItemType: String, Codable {
    case text, image
}

struct ClipboardItem: Identifiable, Equatable, Codable {
    let id: UUID
    let type: ClipboardItemType
    let text: String?
    let imageData: Data?
    let date: Date
    var isPinned: Bool = false

    init(
        id: UUID = UUID(),
        type: ClipboardItemType,
        text: String?,
        image: NSImage?,
        date: Date,
        isPinned: Bool = false
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.imageData = image?.tiffRepresentation
        self.date = date
        self.isPinned = isPinned
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    var image: NSImage? {
        guard let imageData else { return nil }
        return NSImage(data: imageData)
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
    /// The item whose content is currently on the clipboard (marked in the UI).
    @Published var lastCopiedID: UUID?
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    private let settings = AppSettings.shared
    private let persistenceURL: URL

    private init() {
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let containerDirectory = appSupportDirectory
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "ClipboardManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: containerDirectory, withIntermediateDirectories: true)
        persistenceURL = containerDirectory.appendingPathComponent("ClipboardHistory.json")
        loadItems()
        applySettings()
    }

    func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
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
            let maxItems = max(self.settings.maxItems, 1)
            let retainedUnpinned = Array(self.items.filter { !$0.isPinned }.prefix(max(maxItems - 1, 0)))
            let pinned = self.items.filter { $0.isPinned }
            self.items = [item] + retainedUnpinned + pinned
            // Newly captured content is what's on the clipboard now.
            self.lastCopiedID = item.id
            self.applySettings()
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
        lastCopiedID = item.id
    }

    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persistItems()
    }

    func togglePin(_ item: ClipboardItem) {
        if let idx = items.firstIndex(of: item) {
            items[idx].isPinned.toggle()
            persistItems()
        }
    }

    func clearAll() {
        items.removeAll { !$0.isPinned }
        persistItems()
    }

    func applySettings() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -max(settings.retentionDays, 1), to: Date()) ?? .distantPast
        let pinned = items.filter { $0.isPinned }
        let unpinned = items
            .filter { !$0.isPinned }
            .filter { $0.date >= cutoffDate }
        let limitedUnpinned = Array(unpinned.prefix(max(settings.maxItems, 1)))
        let updatedItems = limitedUnpinned + pinned

        if updatedItems != items {
            items = updatedItems
        }

        persistItems()
    }

    private func loadItems() {
        guard let data = try? Data(contentsOf: persistenceURL) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let storedItems = try? decoder.decode([ClipboardItem].self, from: data) else { return }
        items = storedItems.sorted { $0.date > $1.date }
    }

    private func persistItems() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(items)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            NSLog("Failed to persist clipboard history: \(error.localizedDescription)")
        }
    }
}
