#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// Measures what's on the startup disk, category by category like System Settings, then explains System Data.
/// Runs in the background on request; the last map is kept so the bar shows straight away next time.
final class StorageMapper: ObservableObject {
    static let shared = StorageMapper()

    @Published private(set) var segments: [StorageMap.Segment] = []
    @Published private(set) var systemParts: [(part: StorageMap.Part, bytes: Int64)] = []
    @Published private(set) var measured: [StorageMap.Category: Int64] = [:]
    @Published private(set) var mapping = false
    @Published private(set) var progress: String?
    @Published private(set) var mappedAt: Date?
    @Published private(set) var snapshots = 0
    @Published private(set) var needsFullDiskAccess = false

    private let queue = DispatchQueue(label: "monorail.storage.map", qos: .utility)
    private static let savedKey = "StorageMap"

    init() { load() }

    private static func expand(_ path: String, home: URL) -> URL {
        path.hasPrefix("~/") ? home.appendingPathComponent(String(path.dropFirst(2))) : URL(fileURLWithPath: path)
    }

    private static func size(_ paths: [String], home: URL) -> Int64 {
        paths.reduce(Int64(0)) { sum, path in
            let url = expand(path, home: home)
            return FileManager.default.fileExists(atPath: url.path) ? sum + StorageWatch.size(of: url) : sum
        }
    }

    func map() {
        guard !mapping, StorageWatch.shared.canClean else { return }
        mapping = true
        let home = StorageWatch.home
        let storage = StorageWatch.shared
        storage.refresh()
        let used = storage.used
        queue.async { [weak self] in
            guard let self else { return }
            // The volumes: macOS itself, and swap and the sleep image.
            var volumes = StorageMap.Volumes()
            var snapshotCount = 0
            if !Edition.isAppStore {
                let plist = NetworkWatch.run("/usr/sbin/diskutil", ["apfs", "list", "-plist"])
                volumes = StorageMap.volumes(fromDiskutilPlist: Data(plist.utf8)) ?? volumes
                snapshotCount = StorageMap.snapshotCount(fromTmutil: NetworkWatch.run("/usr/bin/tmutil", ["listlocalsnapshots", "/"]))
            }
            // Full Disk Access: macOS keeps Mail and Messages from apps without it.
            let protected = (try? FileManager.default.contentsOfDirectory(atPath: home.appendingPathComponent("Library/Mail").path)) == nil
                && FileManager.default.fileExists(atPath: home.appendingPathComponent("Library/Mail").path)
            var measured: [StorageMap.Category: Int64] = [:]
            for category in StorageMap.Category.allCases where !category.paths.isEmpty {
                DispatchQueue.main.async { self.progress = "Measuring \(category.rawValue)…" }
                measured[category] = Self.size(category.paths, home: home)
                let partial = StorageMap.compose(used: used, measured: measured, macOS: volumes.macOS)
                let soFar = measured
                DispatchQueue.main.async { self.measured = soFar; self.segments = partial }
            }
            // Films in the TV app sit inside Movies, which Documents counts too.
            if let tv = measured[.tv], tv > 0 { measured[.documents] = max((measured[.documents] ?? 0) - tv, 0) }
            let segments = StorageMap.compose(used: used, measured: measured, macOS: volumes.macOS)
            let systemData = segments.first { $0.category == .systemData }?.bytes ?? 0
            var parts: [StorageMap.Part: Int64] = [.swap: volumes.vm]
            for part in StorageMap.Part.allCases where !part.paths.isEmpty {
                DispatchQueue.main.async { self.progress = "Looking at \(part.rawValue.lowercased())…" }
                parts[part] = Self.size(part.paths, home: home)
            }
            // Backups and virtual machines live inside Application Support; count them once.
            let inside = (parts[.backups] ?? 0) + Self.size(["~/Library/Application Support/UTM"], home: home)
            parts[.appSupport] = max((parts[.appSupport] ?? 0) - inside, 0)
            let explained = StorageMap.explain(systemData: systemData, parts: parts)
            let final = measured
            DispatchQueue.main.async {
                self.measured = final
                self.segments = segments
                self.systemParts = explained
                self.snapshots = snapshotCount
                self.needsFullDiskAccess = protected
                self.mappedAt = Date()
                self.mapping = false
                self.progress = nil
                self.save()
            }
        }
    }

    private func save() {
        let record: [String: Any] = [
            "at": mappedAt?.timeIntervalSince1970 ?? 0,
            "segments": segments.map { [$0.category.rawValue: $0.bytes] },
            "parts": systemParts.map { [$0.part.rawValue: $0.bytes] },
            "snapshots": snapshots,
        ]
        UserDefaults.standard.set(record, forKey: Self.savedKey)
    }

    private func load() {
        guard let record = UserDefaults.standard.dictionary(forKey: Self.savedKey) else { return }
        segments = ((record["segments"] as? [[String: Int64]]) ?? []).compactMap { entry in
            entry.first.flatMap { pair in StorageMap.Category(rawValue: pair.key).map { StorageMap.Segment(category: $0, bytes: pair.value) } }
        }
        systemParts = ((record["parts"] as? [[String: Int64]]) ?? []).compactMap { entry in
            entry.first.flatMap { pair -> (part: StorageMap.Part, bytes: Int64)? in StorageMap.Part(rawValue: pair.key).map { (part: $0, bytes: pair.value) } }
        }
        snapshots = record["snapshots"] as? Int ?? 0
        if let at = record["at"] as? TimeInterval, at > 0 { mappedAt = Date(timeIntervalSince1970: at) }
    }
}

extension StorageMap.Category {
    /// Colours close to System Settings' storage bar.
    var colour: Color {
        switch self {
        case .applications: return Color(nsColor: .systemRed)
        case .documents: return Color(nsColor: .systemYellow)
        case .developer: return Color(nsColor: .systemIndigo)
        case .iCloud: return Color(red: 0.35, green: 0.78, blue: 0.98)
        case .mail: return Color(nsColor: .systemBlue)
        case .messages: return Color(nsColor: .systemGreen)
        case .music: return Color(nsColor: .systemOrange)
        case .photos: return Color(nsColor: .systemTeal)
        case .tv: return Color(nsColor: .systemPurple)
        case .trash: return Color(nsColor: .systemBrown)
        case .systemData: return Color(white: 0.56)
        case .macOS: return Color(white: 0.38)
        }
    }

    var symbol: String {
        switch self {
        case .applications: return "app.badge"
        case .documents: return "doc.fill"
        case .developer: return "hammer.fill"
        case .iCloud: return "icloud.fill"
        case .mail: return "envelope.fill"
        case .messages: return "message.fill"
        case .music: return "music.note"
        case .photos: return "photo.fill"
        case .tv: return "tv.fill"
        case .trash: return "trash.fill"
        case .systemData: return "gearshape.2.fill"
        case .macOS: return "apple.logo"
        }
    }
}

/// The bar: one coloured segment per category, then free space, like System Settings → General → Storage.
struct StorageBar: View {
    let segments: [StorageMap.Segment]
    let total: Int64
    let free: Int64
    var height: CGFloat = 20
    @State private var hovered: StorageMap.Category?
    /// The segments grow in from the left when the bar appears.
    @State private var grown: CGFloat = Motion.reduced ? 1 : 0

    var body: some View {
        GeometryReader { g in
            let width = g.size.width
            HStack(spacing: 1.5) {
                ForEach(segments) { segment in
                    let w = max(width * grown * CGFloat(Double(segment.bytes) / Double(max(total, 1))) - 1.5, 2)
                    Rectangle().fill(segment.category.colour.opacity(hovered == nil || hovered == segment.category ? 1 : 0.45))
                        .frame(width: w)
                        .onHover { hovered = $0 ? segment.category : nil }
                        .help("\(segment.category.rawValue): \(Storage.size(segment.bytes))")
                }
                ZStack {
                    Rectangle().fill(Color.primary.opacity(0.1))
                    if height >= 16, width * CGFloat(Double(free) / Double(max(total, 1))) > 80 {
                        Text(Storage.size(free)).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                if let hovered, let segment = segments.first(where: { $0.category == hovered }) {
                    Text("\(hovered.rawValue) · \(Storage.size(segment.bytes))")
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(.regularMaterial))
                        .offset(y: -24)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height >= 16 ? 5 : 3, style: .continuous))
        .onAppear { guard grown < 1 else { return }; withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.15)) { grown = 1 } }
        .animation(.easeOut(duration: 0.3), value: segments)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(segments.map { "\($0.category.rawValue) \(Storage.size($0.bytes))" }.joined(separator: ", ") + ", \(Storage.size(free)) free"))
    }
}

/// The map on the Storage page: the bar with its legend, every category with its size, and System Data explained.
struct StorageMapCard: View {
    @ObservedObject private var storage = StorageWatch.shared
    @ObservedObject private var mapper = StorageMapper.shared
    @State private var showParts = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Macintosh HD").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(Storage.size(storage.used)) of \(Storage.size(storage.total)) used").font(.system(size: 11.5)).foregroundStyle(.secondary).monospacedDigit()
                }
                .padding(.top, 2)
                StorageBar(segments: mapper.segments.isEmpty ? [StorageMap.Segment(category: .systemData, bytes: storage.used)] : mapper.segments,
                           total: storage.total, free: storage.free)
                    .padding(.top, 4)
                legend
                HStack {
                    if mapper.mapping {
                        ProgressView().controlSize(.small)
                        Text(mapper.progress ?? "Measuring…").font(.system(size: 11)).foregroundStyle(.secondary)
                    } else if let at = mapper.mappedAt {
                        Text("Measured \(at.formatted(.relative(presentation: .named)))").font(.system(size: 11)).foregroundStyle(.tertiary)
                    } else {
                        Text("See what's using the space, the way System Settings shows it, and what System Data really is.")
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if storage.canClean {
                        Button(mapper.mappedAt == nil ? "Measure" : "Measure Again") { mapper.map() }.controlSize(.small).disabled(mapper.mapping)
                    }
                }
            }
            .tile()
            if !mapper.segments.isEmpty, mapper.mappedAt != nil { categoriesCard }
            if !mapper.systemParts.isEmpty { systemDataCard }
        }
        .onAppear { if mapper.mappedAt.map({ Date().timeIntervalSince($0) > 6 * 3600 }) ?? false { mapper.map() } }
    }

    private var legend: some View {
        let items = (mapper.segments.isEmpty ? [] : mapper.segments)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 4) {
            ForEach(items) { segment in
                HStack(spacing: 4) {
                    Circle().fill(segment.category.colour).frame(width: 7, height: 7)
                    Text(segment.category.rawValue).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(mapper.segments) { segment in
                HStack(spacing: 9) {
                    Image(systemName: segment.category.symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 24, height: 24).background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(segment.category.colour))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(segment.category.rawValue).font(.system(size: 12, weight: .medium))
                        Text(segment.category.detail).font(.system(size: 10.5)).foregroundStyle(.tertiary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(Storage.size(segment.bytes)).font(.figure(12, weight: .semibold))
                    if let first = segment.category.paths.first {
                        Button {
                            let url = first.hasPrefix("~/") ? StorageWatch.home.appendingPathComponent(String(first.dropFirst(2))) : URL(fileURLWithPath: first)
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: { Image(systemName: "magnifyingglass").font(.system(size: 10)).accessibilityLabel("Show \(segment.category.rawValue) in Finder") }
                        .buttonStyle(.plain).help("Show in Finder")
                    }
                }
                .padding(.vertical, 4)
            }
            if mapper.needsFullDiskAccess {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(Tone.ok)
                    Text("Mail, Messages and the Trash are measured only with Full Disk Access; until then they count as System Data.")
                        .font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Open Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") { NSWorkspace.shared.open(url) }
                    }
                    .controlSize(.mini)
                }
                .padding(.top, 4)
            }
        }
        .tile()
    }

    private var systemDataCard: some View {
        let total = mapper.segments.first { $0.category == .systemData }?.bytes ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation(Motion.reorder) { showParts.toggle() } } label: {
                HStack {
                    Text("WHAT'S IN SYSTEM DATA").font(.label).foregroundStyle(.secondary)
                    Spacer()
                    Text(Storage.size(total)).font(.figure(12, weight: .semibold))
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary).rotationEffect(.degrees(showParts ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            if showParts {
                ForEach(Array(mapper.systemParts.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.part.rawValue).font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text(Storage.size(item.bytes)).font(.figure(11.5, weight: .semibold))
                        }
                        GeometryReader { g in
                            Capsule().fill(Color(white: 0.56)).frame(width: max(3, g.size.width * CGFloat(Double(item.bytes) / Double(max(total, 1)))))
                        }
                        .frame(height: 4)
                        Text(item.part.advice).font(.system(size: 10.5)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 3)
                }
                if mapper.snapshots > 0 {
                    Text("\(mapper.snapshots) Time Machine snapshot\(mapper.snapshots == 1 ? "" : "s") on this Mac: macOS frees their space by itself when it's needed.")
                        .font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tile()
    }
}
#endif
