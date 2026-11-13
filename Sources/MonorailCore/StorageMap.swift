import Foundation

/// What's on the startup disk, the way System Settings shows it: a bar of categories (Applications,
/// Documents, Photos…, System Data, macOS), and then what System Settings won't say: what System Data is.
public enum StorageMap {
    /// The categories, in System Settings' order. Colours are the app's to choose.
    public enum Category: String, CaseIterable, Sendable, Identifiable {
        case applications = "Applications", documents = "Documents", developer = "Developer", iCloud = "iCloud Drive",
             mail = "Mail", messages = "Messages", music = "Music", photos = "Photos", tv = "TV", trash = "Trash",
             systemData = "System Data", macOS = "macOS"
        public var id: String { rawValue }

        /// Folders measured for this category, relative to the home folder ("~/") or absolute ("/").
        public var paths: [String] {
            switch self {
            case .applications: return ["/Applications", "~/Applications"]
            case .documents: return ["~/Documents", "~/Desktop", "~/Downloads", "~/Movies", "~/Public"]
            case .developer: return ["~/Library/Developer", "/Library/Developer"]
            case .iCloud: return ["~/Library/Mobile Documents"]
            case .mail: return ["~/Library/Mail"]
            case .messages: return ["~/Library/Messages"]
            case .music: return ["~/Music"]
            case .photos: return ["~/Pictures"]
            case .tv: return ["~/Movies/TV"]
            case .trash: return ["~/.Trash"]
            case .systemData, .macOS: return []
            }
        }

        /// One line on what's in it.
        public var detail: String {
            switch self {
            case .applications: return "Apps in Applications, yours and the Mac's."
            case .documents: return "Documents, Desktop, Downloads and Movies."
            case .developer: return "Xcode's build files, simulators, archives and device support."
            case .iCloud: return "Files kept on this Mac from iCloud Drive."
            case .mail: return "Mail messages and attachments downloaded to this Mac."
            case .messages: return "Messages and their attachments."
            case .music: return "Your music library and downloads."
            case .photos: return "Your Photos library and Pictures."
            case .tv: return "Films and shows downloaded in the TV app."
            case .trash: return "Things in the Trash: empty it to get the space back."
            case .systemData: return "Caches, logs, snapshots, swap and other files the Mac and apps keep."
            case .macOS: return "macOS itself, on its own sealed, read-only volume."
            }
        }

        /// Measuring it needs Full Disk Access (macOS protects these folders).
        public var needsFullDiskAccess: Bool { self == .mail || self == .messages || self == .trash }
    }

    /// What System Data is made of, as far as the Mac lets an app look.
    public enum Part: String, CaseIterable, Sendable, Identifiable {
        case snapshots = "Time Machine snapshots", swap = "Swap and sleep image", caches = "Caches", logs = "Logs",
             backups = "iPhone and iPad backups", containers = "App data (containers)", appSupport = "Application Support",
             models = "Apple Intelligence and system assets", docker = "Docker and virtual machines", updates = "Software updates",
             other = "Everything else"
        public var id: String { rawValue }

        /// Folders measured for this part. App containers aren't measured automatically: looking inside another
        /// app's container makes macOS ask for permission, so they stay in "Everything else".
        public var paths: [String] {
            switch self {
            case .caches: return ["~/Library/Caches", "/Library/Caches"]
            case .logs: return ["~/Library/Logs", "/Library/Logs"]
            case .backups: return ["~/Library/Application Support/MobileSync/Backup"]
            case .containers: return []
            case .appSupport: return ["~/Library/Application Support"]
            case .models: return ["/System/Library/AssetsV2", "/Library/Apple/System/Library/AssetsV2"]
            case .docker: return ["~/.docker", "~/.colima", "~/.orbstack", "~/Parallels", "~/Virtual Machines.localized", "~/Library/Application Support/UTM"]
            case .updates: return ["/Library/Updates"]
            case .snapshots, .swap, .other: return []
            }
        }

        public var advice: String {
            switch self {
            case .snapshots: return "Kept by Time Machine on this Mac until it backs up; macOS removes them as space is needed."
            case .swap: return "Memory written to disk when RAM is full, and the copy of memory kept for sleep. A restart shrinks swap."
            case .caches: return "Apps rebuild these when needed. Safe to clear, but apps may be slower the first time after."
            case .logs: return "Records apps and macOS write. Old ones are safe to delete."
            case .backups: return "Full backups of your iPhone or iPad. Delete old ones in Finder: select the device, Manage Backups."
            case .containers: return "Each sandboxed app's own files and settings. Large ones usually mean a big app library."
            case .appSupport: return "Apps' saved data: libraries, models, offline files."
            case .models: return "Apple Intelligence models, voices, fonts and other things macOS downloads."
            case .docker: return "Disk images for Docker, Colima, OrbStack or virtual machines. Prune them from those apps."
            case .updates: return "Downloaded macOS updates waiting to install."
            case .other: return "Space the Mac uses that no app can see, such as purgeable files and other users."
            }
        }
    }

    public struct Segment: Equatable, Sendable, Identifiable {
        public var category: Category
        public var bytes: Int64
        public var id: String { category.rawValue }
        public init(category: Category, bytes: Int64) { self.category = category; self.bytes = bytes }
    }

    /// The bar: measured categories (largest first, small ones folded), then System Data and macOS.
    /// `used` is the space in use; System Data is what's left after everything that was measured.
    public static func compose(used: Int64, measured: [Category: Int64], macOS: Int64) -> [Segment] {
        var segments: [Segment] = []
        var counted: Int64 = 0
        for category in Category.allCases where category != .systemData && category != .macOS {
            let bytes = max(measured[category] ?? 0, 0)
            guard bytes > 0 else { continue }
            segments.append(Segment(category: category, bytes: bytes))
            counted += bytes
        }
        segments.sort { $0.bytes > $1.bytes }
        let system = max(used - counted - macOS, 0)
        if system > 0 { segments.append(Segment(category: .systemData, bytes: system)) }
        if macOS > 0 { segments.append(Segment(category: .macOS, bytes: macOS)) }
        return segments
    }

    /// System Data broken down: the parts that were measured, then "Everything else" for the rest.
    public static func explain(systemData: Int64, parts: [Part: Int64]) -> [(part: Part, bytes: Int64)] {
        var list: [(part: Part, bytes: Int64)] = []
        var counted: Int64 = 0
        for part in Part.allCases where part != .other {
            let bytes = max(parts[part] ?? 0, 0)
            guard bytes > 0 else { continue }
            list.append((part, bytes))
            counted += bytes
        }
        list.sort { $0.bytes > $1.bytes }
        let rest = systemData - counted
        if rest > 0 { list.append((.other, rest)) }
        return list
    }

    /// The APFS volumes on the startup container, from `diskutil apfs list -plist`: the space macOS itself
    /// uses (System, Preboot, Recovery, Update) and the VM volume (swap and sleep image).
    public struct Volumes: Equatable, Sendable {
        public var macOS: Int64 = 0
        public var vm: Int64 = 0
        public var data: Int64 = 0
        public init(macOS: Int64 = 0, vm: Int64 = 0, data: Int64 = 0) { self.macOS = macOS; self.vm = vm; self.data = data }
    }

    /// Reads the volumes of the container that holds `dataVolume` (by its BSD name, e.g. "disk3s5"), or the first
    /// container with a Data volume.
    public static func volumes(fromDiskutilPlist data: Data) -> Volumes? {
        guard let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let containers = root["Containers"] as? [[String: Any]] else { return nil }
        for container in containers {
            let vols = container["Volumes"] as? [[String: Any]] ?? []
            let roles = vols.map { ($0["Roles"] as? [String]) ?? [] }
            guard roles.contains(where: { $0.contains("Data") }) else { continue }
            var result = Volumes()
            for (volume, role) in zip(vols, roles) {
                let used = (volume["CapacityInUse"] as? NSNumber)?.int64Value ?? 0
                if role.contains("Data") { result.data += used }
                else if role.contains("VM") { result.vm += used }
                else if role.contains("System") || role.contains("Preboot") || role.contains("Recovery") || role.contains("Update") { result.macOS += used }
            }
            return result
        }
        return nil
    }

    /// The number of Time Machine snapshots in `tmutil listlocalsnapshots /` output.
    public static func snapshotCount(fromTmutil text: String) -> Int {
        text.split(separator: "\n").filter { $0.contains("com.apple.TimeMachine") }.count
    }
}
