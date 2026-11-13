#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

/// The startup disk: free space, safe clean-ups (Monorail) and the largest items in a folder.
/// Everything removed goes to the Trash first, so it can be put back.
final class StorageWatch: ObservableObject {
    static let shared = StorageWatch()

    struct Found: Identifiable, Equatable {
        var id: String
        var bytes: Int64
        var urls: [URL]
    }

    @Published private(set) var free: Int64 = 0
    @Published private(set) var total: Int64 = 0
    @Published private(set) var cleanups: [String: Found] = [:]
    @Published private(set) var scanning = false
    @Published private(set) var largest: [Storage.Item] = []
    @Published private(set) var largestFolder: URL?
    @Published private(set) var cleaned: Int64 = 0

    private var timer: Timer?
    private var warned: Storage.Level = .fine
    private let queue = DispatchQueue(label: "monorail.storage", qos: .utility)

    var level: Storage.Level { Storage.level(free: free, total: total) }
    var used: Int64 { max(total - free, 0) }
    /// Signalbox looks at your home folder only after you choose it once in the Open dialog
    /// (the App Store's rule); it remembers that choice with a security-scoped bookmark.
    @Published private(set) var granted: URL?
    var canClean: Bool { !Edition.isAppStore || granted != nil }

    /// The real home folder, not the sandbox's container.
    static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir { return URL(fileURLWithPath: String(cString: dir)) }
        return FileManager.default.homeDirectoryForCurrentUser
    }
    static var home: URL { shared.granted ?? realHome }

    private static let bookmarkKey = "StorageHomeBookmark"

    init() {
        guard Edition.isAppStore, let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale),
           url.startAccessingSecurityScopedResource() {
            granted = url
            if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(fresh, forKey: Self.bookmarkKey)
            }
        }
    }

    /// Signalbox: ask once for the home folder, so clean-ups and the full scan can see it.
    func grantHome() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = Self.realHome
        panel.prompt = "Allow"
        panel.message = "Choose your home folder (\(Self.realHome.lastPathComponent)) so \(Brand.name) can find space to free up. Nothing leaves your Mac, and everything removed goes to the Trash first."
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        granted?.stopAccessingSecurityScopedResource()
        _ = url.startAccessingSecurityScopedResource()
        granted = url
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
        }
        cleanups = [:]
        scanCleanups()
    }

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.every(1800) { [weak self] _ in self?.refresh() }
        timer?.tolerance = 300
    }

    func refresh() {
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        total = Int64(values?.volumeTotalCapacity ?? 0)
        free = values?.volumeAvailableCapacityForImportantUsage ?? 0
        let now = level
        if now != .fine, now != warned {
            notify(now == .critical ? "Your disk is almost full" : "Disk space is getting low",
                   "\(Storage.size(free)) left. Open \(Brand.name) to see what you can clear.")
        }
        warned = now
    }

    // MARK: Clean-ups

    func scanCleanups() {
        guard canClean, !scanning else { return }
        scanning = true
        let home = Self.home
        queue.async { [weak self] in
            var found: [String: Found] = [:]
            for cleanup in Storage.cleanups {
                var urls: [URL] = [], bytes: Int64 = 0
                for path in cleanup.paths {
                    let folder = home.appendingPathComponent(path)
                    let children = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentAccessDateKey, .contentModificationDateKey])) ?? []
                    for child in children {
                        let v = try? child.resourceValues(forKeys: [.contentAccessDateKey, .contentModificationDateKey])
                        guard Storage.isOld(lastUsed: v?.contentAccessDate, modified: v?.contentModificationDate, days: cleanup.olderThanDays) else { continue }
                        let size = Self.size(of: child)
                        guard size > 0 else { continue }
                        urls.append(child)
                        bytes += size
                    }
                }
                if bytes > 0 { found[cleanup.id] = Found(id: cleanup.id, bytes: bytes, urls: urls) }
            }
            DispatchQueue.main.async {
                self?.cleanups = found
                self?.scanning = false
            }
        }
    }

    func clean(_ id: String) {
        guard canClean, let found = cleanups[id] else { return }
        queue.async { [weak self] in
            var freed: Int64 = 0
            for url in found.urls {
                let size = Self.size(of: url)
                if (try? FileManager.default.trashItem(at: url, resultingItemURL: nil)) != nil { freed += size }
            }
            DispatchQueue.main.async {
                self?.cleanups[id] = nil
                self?.cleaned += freed
                self?.refresh()
            }
        }
    }

    // MARK: Largest items

    /// Monorail looks in your home folder; Signalbox looks only in a folder you choose.
    func findLargest(in folder: URL? = nil) {
        if folder == nil, Edition.isAppStore, granted == nil {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.prompt = "Look Inside"
            panel.message = "Choose a folder to find what's taking up space in it."
            NSApp.activate(ignoringOtherApps: true)
            guard panel.runModal() == .OK, let url = panel.url else { return }
            return findLargest(in: url)
        }
        let target = folder ?? Self.home
        scanning = true
        largestFolder = target
        queue.async { [weak self] in
            var items: [Storage.Item] = []
            let skip: Set<String> = ["Library", ".Trash"]
            let children = (try? FileManager.default.contentsOfDirectory(at: target, includingPropertiesForKeys: nil)) ?? []
            for child in children where !skip.contains(child.lastPathComponent) {
                // Folders one level down, so a big folder points at what's big inside it.
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: child.path, isDirectory: &isDir)
                let grandchildren = isDir.boolValue ? ((try? FileManager.default.contentsOfDirectory(at: child, includingPropertiesForKeys: nil)) ?? []) : [child]
                for item in grandchildren where !(child.pathExtension == "app") {
                    items.append(Storage.Item(path: item.path, bytes: Self.size(of: item)))
                }
                if child.pathExtension == "app" { items.append(Storage.Item(path: child.path, bytes: Self.size(of: child))) }
            }
            let top = Storage.largest(items)
            DispatchQueue.main.async {
                self?.largest = top
                self?.scanning = false
            }
        }
    }

    static func size(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        if let v = try? url.resourceValues(forKeys: keys), v.isRegularFile == true { return Int64(v.totalFileAllocatedSize ?? 0) }
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true }) else { return 0 }
        var sum: Int64 = 0
        for case let file as URL in walker {
            if let v = try? file.resourceValues(forKeys: keys), v.isRegularFile == true { sum += Int64(v.totalFileAllocatedSize ?? 0) }
        }
        return sum
    }

    private func notify(_ title: String, _ body: String) {
        guard !SuiteRole.shared.pauses(.notifications) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}

private struct StoragePageHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private func levelColour(_ level: Storage.Level) -> Color {
    switch level {
    case .fine: return Color(nsColor: .systemBlue)
    case .low: return Color(nsColor: .systemOrange)
    case .critical: return Color(nsColor: .systemRed)
    }
}

/// Home's storage card: free space and a bar.
struct StorageWidget: View {
    let open: () -> Void
    @ObservedObject private var storage = StorageWatch.shared
    @ObservedObject private var mapper = StorageMapper.shared

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 6) {
                CardTitle(title: "STORAGE", symbol: "internaldrive.fill", tint: levelColour(storage.level))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Storage.size(storage.free)).font(.figure(20)).rolling(Storage.size(storage.free))
                    Text("free").font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                if mapper.segments.isEmpty {
                    ProgressView(value: Double(storage.used), total: Double(max(storage.total, 1))).tint(levelColour(storage.level))
                } else {
                    // The same colours as the Storage page and System Settings.
                    StorageBar(segments: mapper.segments, total: storage.total, free: storage.free, height: 7)
                }
            }
            .tile()
        }
        .buttonStyle(PressStyle())
        .onAppear { storage.start() }
        .accessibilityLabel(Text("Storage: \(Storage.size(storage.free)) free. Opens the Storage page"))
    }
}

/// The Storage page.
struct StoragePage: View {
    let onBack: () -> Void
    /// Inside the dashboard: no back button.
    var embedded = false
    @ObservedObject private var storage = StorageWatch.shared
    @State private var contentHeight: CGFloat = 480

    var body: some View {
        if embedded { content } else {
            // In the panel: as tall as its content, up to a limit; then it scrolls.
            ScrollView {
                content.background(GeometryReader { proxy in Color.clear.preference(key: StoragePageHeight.self, value: proxy.size.height) })
            }
            .onPreferenceChange(StoragePageHeight.self) { contentHeight = $0 }
            .frame(height: min(max(contentHeight, 200), 640))
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !embedded { PageHeader(back: Brand.name, title: "Storage", onBack: onBack) }
            if storage.level != .fine {
                Label(storage.level == .critical ? "Almost full: the Mac slows down and updates can fail." : "Getting low: clear some space soon.",
                      systemImage: "exclamationmark.triangle.fill").font(.system(size: 11.5)).foregroundStyle(levelColour(storage.level))
                    .padding(.horizontal, 4)
            }
            StorageMapCard()
            if storage.canClean { cleanupsCard } else { grantCard }
            largestCard
        }
        .padding(12)
        .onAppear {
            storage.refresh()
            if storage.cleanups.isEmpty { storage.scanCleanups() }
        }
    }

    private var grantCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FIND SPACE TO FREE UP").font(.label).foregroundStyle(.secondary)
            Text("Xcode build files, old caches and downloads you've forgotten. Choose your home folder once, and \(Brand.name) can look.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Choose Home Folder…") { storage.grantHome() }.controlSize(.small)
        }
        .tile()
    }

    private var cleanupsCard: some View {
        let total = storage.cleanups.values.reduce(Int64(0)) { $0 + $1.bytes }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(total > 0 ? "YOU CAN GET BACK \(Storage.size(total).uppercased())" : "CLEAN-UPS").font(.label).foregroundStyle(.secondary)
                Spacer()
                if storage.scanning { ProgressView().controlSize(.small) }
            }
            if storage.cleaned > 0 {
                Text("Moved \(Storage.size(storage.cleaned)) to the Trash. Empty it to get the space back.").font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            ForEach(Storage.cleanups.filter { storage.cleanups[$0.id] != nil }) { cleanup in
                HStack(spacing: 8) {
                    Image(systemName: cleanup.symbol).font(.system(size: 11)).foregroundStyle(.white)
                        .frame(width: 24, height: 24).background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .systemPurple)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(cleanup.title).font(.system(size: 12, weight: .medium))
                        Text(cleanup.detail).font(.system(size: 10.5)).foregroundStyle(.tertiary).lineLimit(1)
                    }
                    Spacer()
                    Text(Storage.size(storage.cleanups[cleanup.id]?.bytes ?? 0)).font(.system(size: 12, weight: .semibold)).monospacedDigit()
                    Button("Clean") { storage.clean(cleanup.id) }.controlSize(.small)
                }
            }
            if !storage.scanning && storage.cleanups.isEmpty {
                Text("Nothing to clear right now.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Text("Everything goes to the Trash first.").font(.system(size: 10.5)).foregroundStyle(.tertiary)
        }
        .tile()
    }

    private var largestCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LARGEST ITEMS").font(.label).foregroundStyle(.secondary)
                Spacer()
                Button(Edition.isAppStore && !storage.canClean ? "Choose Folder…" : (storage.largest.isEmpty ? "Find" : "Look Again")) { storage.findLargest() }
                    .buttonStyle(.link).font(.system(size: 11)).disabled(storage.scanning)
            }
            if storage.largest.isEmpty {
                Text(Edition.isAppStore && !storage.canClean ? "Pick a folder to see what's big inside it." : "Finds the biggest things in your home folder.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            ForEach(storage.largest, id: \.path) { item in
                HStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.path)).resizable().frame(width: 18, height: 18)
                    Text((item.path as NSString).abbreviatingWithTildeInPath).font(.system(size: 11.5)).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(Storage.size(item.bytes)).font(.system(size: 11.5, weight: .semibold)).monospacedDigit()
                    Button { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)]) } label: {
                        Image(systemName: "magnifyingglass").font(.system(size: 10)).accessibilityLabel("Show in Finder")
                    }
                    .buttonStyle(.plain).help("Show in Finder")
                }
            }
        }
        .tile()
    }
}
#endif
