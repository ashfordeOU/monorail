#if os(macOS)
import AppKit
import CryptoKit
import MonorailCore
import Security
import SwiftUI

/// Keeps Monorail up to date: finds a newer version on monorail.ashforde.org,
/// downloads it, checks its SHA-256 checksum and code signature, swaps it in
/// and relaunches. The update check can be turned off in Settings.
final class Updater: ObservableObject {
    static let releasesURL = URL(string: "https://monorail.ashforde.org/changelog/")!
    /// The website's copy of the newest release (scripts/mirror-releases.py), in GitHub's format.
    private static let feedURL = URL(string: "https://monorail.ashforde.org/releases/latest.json")!
    /// With betas: the newest few releases, including pre-releases.
    private static let allReleasesFeedURL = URL(string: "https://monorail.ashforde.org/releases/index.json")!
    /// Used only if the website can't be reached.
    private static let apiURL = URL(string: "https://api.github.com/repos/ashfordeOU/monorail/releases/latest")!
    private static let allReleasesURL = URL(string: "https://api.github.com/repos/ashfordeOU/monorail/releases?per_page=10")!
    /// Also offer beta (pre-release) versions.
    var betaChannel = false
    private static let lastCheckKey = "lastUpdateCheck"
    private static let skippedKey = "skippedVersion"

    struct Release {
        var version: String
        var archive: URL
        var checksums: URL
    }

    /// A newer release, once one has been found.
    @Published private(set) var available: Release?
    @Published private(set) var isInstalling = false
    /// What an install is doing now ("Downloading", "Checking", "Restarting"), for the panel.
    @Published private(set) var stage: String?
    /// The new version's notes from the website's changelog, once read.
    @Published private(set) var notes: [String] = []
    /// Set when "Tonight" was chosen: installs between 1 and 5 am while the Mac is idle.
    @Published private(set) var installsTonight = false
    /// Opens the panel at the update, for checks you asked for.
    var showUpdate: () -> Void = {}
    private static let changelogURL = URL(string: "https://monorail.ashforde.org/changelog/CHANGELOG.md")!
    private var tonightTimer: Timer?

    /// Install without asking when a check finds a new version.
    var installAutomatically = false
    /// Called just before Monorail quits to relaunch the new version.
    var willRelaunch: () -> Void = {}

    private var timer: Timer?
    private let hud = UpdateHUD()

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Checks at most once a day while `enabled`.
    func setAutomatic(_ enabled: Bool) {
        timer?.invalidate()
        timer = nil
        guard enabled else { return }
        timer = Timer.every(3600) { [weak self] _ in self?.checkIfDue() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.checkIfDue() }
    }

    private func checkIfDue() {
        let last = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        guard Date().timeIntervalSince1970 - last > 86_400 else { return }
        check(userInitiated: false)
    }

    // MARK: - Checking

    /// Looks up the latest release. User-initiated checks always report back.
    func check(userInitiated: Bool) {
        // The App Store keeps the App Store edition up to date.
        guard !Edition.isAppStore else { return }
        let urls = betaChannel ? [Self.allReleasesFeedURL, Self.allReleasesURL] : [Self.feedURL, Self.apiURL]
        Self.fetchRelease(from: urls) { [weak self] release in
            DispatchQueue.main.async {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)
                guard let self else { return }
                guard let release else {
                    if userInitiated {
                        self.alert("Couldn’t check for updates", "Check your internet connection and try again.")
                    }
                    return
                }
                guard Self.isNewer(release.version, than: self.currentVersion) else {
                    self.available = nil
                    if userInitiated {
                        self.alert("Monorail is up to date", "Version \(self.currentVersion) is the latest.")
                    }
                    return
                }
                self.available = release
                self.fetchNotes(for: release.version)
                if self.installAutomatically && !userInitiated {
                    self.install(release)
                } else if userInitiated {
                    // No alert: the panel opens at the update, with what's new and Update Now.
                    self.showUpdate()
                }
                // Found by itself, it waits quietly as a card at the top of the panel.
            }
        }
    }

    /// Tries each address in turn and hands back the first release it can read.
    private static func fetchRelease(from urls: [URL], completion: @escaping (Release?) -> Void) {
        guard let url = urls.first else { return completion(nil) }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let ok = error == nil && ((response as? HTTPURLResponse)?.statusCode ?? 0) == 200
            if ok, let data, let release = parse(data) { return completion(release) }
            fetchRelease(from: Array(urls.dropFirst()), completion: completion)
        }.resume()
    }

    private static func parse(_ data: Data) -> Release? {
        let object = try? JSONSerialization.jsonObject(with: data)
        // The beta channel gets a list: take the newest Mac release that isn't a draft (Mac
        // versions are tagged vX.Y.Z; the Windows and Linux betas share the list under other tags).
        let candidate = (object as? [[String: Any]])?.first {
            ($0["draft"] as? Bool) != true && (($0["tag_name"] as? String)?.hasPrefix("v") ?? false)
        } ?? object as? [String: Any]
        guard let json = candidate,
            let tag = json["tag_name"] as? String,
            let assets = json["assets"] as? [[String: Any]]
        else { return nil }
        func asset(_ match: (String) -> Bool) -> URL? {
            assets.first { ($0["name"] as? String).map(match) ?? false }
                .flatMap { $0["browser_download_url"] as? String }
                .flatMap(URL.init(string:))
        }
        guard let archive = asset({ $0.hasPrefix("Monorail-") && $0.hasSuffix(".zip") })
                ?? asset({ $0.hasPrefix("MacSlider-") && $0.hasSuffix(".zip") }),
            let checksums = asset({ $0 == "SHA256SUMS" })
        else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return Release(version: version, archive: archive, checksums: checksums)
    }

    /// Betas count as older than their final release (see `Version`).
    static func isNewer(_ a: String, than b: String) -> Bool {
        Version.isNewer(a, than: b)
    }

    /// Installs the release found by the last check.
    func installAvailable() {
        if let available { install(available) } else { check(userInitiated: true) }
    }

    /// Reads the new version's part of the changelog, for What's New before installing.
    private func fetchNotes(for version: String) {
        notes = []
        var request = URLRequest(url: Self.changelogURL, timeoutInterval: 15)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data, let text = String(data: data, encoding: .utf8) else { return }
            let lines = ReleaseNotes.section(version, in: text)
            DispatchQueue.main.async { self?.notes = lines }
        }.resume()
    }

    /// "Tonight": installs between 1 and 5 am once nobody has touched the Mac for 15 minutes,
    /// so nothing restarts while you work.
    func installTonight() {
        guard available != nil else { return }
        installsTonight = true
        tonightTimer?.invalidate()
        tonightTimer = Timer.every(600) { [weak self] _ in
            guard let self, let release = self.available, !self.isInstalling else { return }
            let hour = Calendar.current.component(.hour, from: Date())
            let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
            guard (1...4).contains(hour), idle > 900 else { return }
            self.tonightTimer?.invalidate()
            self.install(release)
        }
    }

    func cancelTonight() {
        installsTonight = false
        tonightTimer?.invalidate()
        tonightTimer = nil
    }

    // MARK: - Installing

    enum UpdateError: LocalizedError {
        case notWritable(String)
        case download
        case checksum
        case unpack
        case signature

        var errorDescription: String? {
            switch self {
            case .notWritable(let path): return "Monorail can’t replace itself at \(path)."
            case .download: return "The download didn’t complete."
            case .checksum: return "The download didn’t match its published checksum."
            case .unpack: return "The download couldn’t be opened."
            case .signature: return "The new version isn’t signed the same way as this one."
            }
        }
    }

    func install(_ release: Release) {
        guard !isInstalling else { return }
        let destination = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: destination.deletingLastPathComponent().path) else {
            fail(UpdateError.notWritable(destination.deletingLastPathComponent().path))
            return
        }
        isInstalling = true
        stage = "Downloading"
        hud.show("Updating to Monorail \(release.version)", detail: "Downloading…")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let app = try Self.downloadAndVerify(release)
                DispatchQueue.main.async {
                    self.stage = "Installing"
                    self.hud.show("Updating to Monorail \(release.version)", detail: "Installing…")
                    self.relaunch(into: app, replacing: destination)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.stage = nil
                    self.hud.hide()
                    self.fail(error)
                }
            }
        }
    }

    /// Downloads the archive and checksums, verifies both, unpacks the app
    /// and checks its signature. Runs off the main thread.
    private static func downloadAndVerify(_ release: Release) throws -> URL {
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("Monorail-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        guard let archive = try? Data(contentsOf: release.archive),
            let sums = try? String(contentsOf: release.checksums, encoding: .utf8)
        else { throw UpdateError.download }

        let name = release.archive.lastPathComponent
        let digest = SHA256.hash(data: archive)
        let actual = digest.map { String(format: "%02x", $0) }.joined()
        guard let expected = checksum(for: name, in: sums), expected == actual else { throw UpdateError.checksum }

        let zip = work.appendingPathComponent(name)
        try archive.write(to: zip)
        let unpack = Process()
        unpack.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unpack.arguments = ["-x", "-k", zip.path, work.path]
        try unpack.run()
        unpack.waitUntilExit()
        // Releases ship Monorail.app; MacSlider.app was its earlier name.
        let app = ["Monorail.app", "MacSlider.app"].map { work.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) } ?? work.appendingPathComponent("Monorail.app")
        guard unpack.terminationStatus == 0, FileManager.default.fileExists(atPath: app.path) else {
            throw UpdateError.unpack
        }
        guard signatureMatchesRunningApp(app) else { throw UpdateError.signature }
        return app
    }

    /// The checksum listed for `file` in a `shasum -a 256` output.
    private static func checksum(for file: String, in sums: String) -> String? {
        for line in sums.split(separator: "\n") {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            if fields.count == 2, fields[1] == file { return fields[0].lowercased() }
        }
        return nil
    }

    /// The new app must carry a valid signature that satisfies this app's own
    /// designated requirement (same identifier, same certificate) or Ashforde's
    /// Developer ID, so only builds signed by Ashforde can replace it. A local
    /// ad-hoc build has no certificate to compare, so it only checks validity.
    private static func signatureMatchesRunningApp(_ app: URL) -> Bool {
        var newCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &newCode) == errSecSuccess, let newCode else {
            return false
        }
        var requirement: SecRequirement?
        var selfCode: SecCode?
        var selfStatic: SecStaticCode?
        if SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode,
            SecCodeCopyStaticCode(selfCode, [], &selfStatic) == errSecSuccess, let selfStatic
        {
            var designated: SecRequirement?
            if SecCodeCopyDesignatedRequirement(selfStatic, [], &designated) == errSecSuccess, let designated {
                var text: CFString?
                SecRequirementCopyString(designated, [], &text)
                // Ad-hoc requirements pin a single build's hash; nothing else can match them.
                if let text = text as String?, !text.contains("cdhash") {
                    requirement = designated
                    // Monorail is moving from the old identifier to org.ashforde.monorail: either may
                    // replace the other, as long as the certificate is the same.
                    let both = "(identifier \"\(BundleIDs.legacy)\" or identifier \"\(BundleIDs.current)\")"
                    let widened = text
                        .replacingOccurrences(of: "identifier \"\(BundleIDs.legacy)\"", with: both)
                        .replacingOccurrences(of: "identifier \"\(BundleIDs.current)\"", with: both)
                    // …and builds signed with Ashforde's Developer ID may replace self-signed ones
                    // (the move to notarised releases), never the other way round.
                    let allowed = CodeSigning.updateRequirement(running: widened, identifiers: BundleIDs.all)
                    var relaxed: SecRequirement?
                    if SecRequirementCreateWithString(allowed as CFString, [], &relaxed) == errSecSuccess {
                        requirement = relaxed
                    } else if widened != text, SecRequirementCreateWithString(widened as CFString, [], &relaxed) == errSecSuccess {
                        requirement = relaxed
                    }
                }
            }
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate)
        return SecStaticCodeCheckValidity(newCode, flags, requirement) == errSecSuccess
    }

    /// Hands over to a small script that waits for Monorail to quit, swaps
    /// the app bundle (rolling back if that fails) and opens the new version.
    /// The new version is installed next to the running one as Monorail.app,
    /// which also renames copies installed under the old name, MacSlider.app.
    private func relaunch(into app: URL, replacing destination: URL) {
        let script = """
            pid="$1"; new="$2"; old="$3"; dest="$(dirname "$old")/Monorail.app"
            while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
            rm -rf "$old.previous"
            if mv "$old" "$old.previous" && /usr/bin/ditto "$new" "$dest"; then
                rm -rf "$old.previous"
            else
                rm -rf "$dest"; mv "$old.previous" "$old"; dest="$old"
            fi
            /usr/bin/xattr -dr com.apple.quarantine "$dest" 2>/dev/null
            rm -rf "$(dirname "$new")"
            /usr/bin/open "$dest"
            """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            "-c", script, "monorail-update",
            String(ProcessInfo.processInfo.processIdentifier), app.path, destination.path,
        ]
        do {
            try process.run()
        } catch {
            isInstalling = false
            stage = nil
            hud.hide()
            fail(error)
            return
        }
        stage = "Restarting"
        hud.show("Restarting Monorail", detail: "Your windows stay where they are")
        willRelaunch()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { NSApp.terminate(nil) }
    }

    private func fail(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Monorail couldn’t update itself"
        alert.informativeText = "\(error.localizedDescription) You can download the new version from GitHub instead."
        alert.addButton(withTitle: "Open Download Page")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(Self.releasesURL) }
    }

    private func alert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

/// A small floating notice while an update installs, for when the panel is closed: the app icon
/// with a turning ring, a title and a line under it, on glass. It slides down from the top.
private final class UpdateHUD {
    private var panel: NSPanel?
    private let model = Model()

    final class Model: ObservableObject {
        @Published var title = ""
        @Published var detail = ""
    }

    func show(_ title: String, detail: String) {
        model.title = title
        model.detail = detail
        let panel = self.panel ?? makePanel()
        let firstShow = !panel.isVisible
        self.panel = panel
        guard let screen = NSScreen.main?.visibleFrame else { return }
        let target = NSPoint(x: screen.maxX - 340 - 16, y: screen.maxY - 72 - 12)
        if firstShow {
            panel.setFrameOrigin(NSPoint(x: target.x, y: target.y + (Motion.reduced ? 0 : 24)))
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Motion.reduced ? 0.1 : 0.35
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 1.2, 0.4, 1)
                panel.animator().setFrameOrigin(target)
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 72),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
        return panel
    }

    private struct HUDView: View {
        @ObservedObject var model: Model
        @State private var turning = false

        var body: some View {
            HStack(spacing: 12) {
                ZStack {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 30, height: 30)
                    Circle().trim(from: 0, to: 0.28)
                        .stroke(Tone.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(turning ? 360 : 0))
                        .animation(Motion.reduced ? nil : .linear(duration: 1).repeatForever(autoreverses: false), value: turning)
                }
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title).font(.system(size: 13, weight: .semibold))
                    Text(model.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(width: 340, height: 72)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onAppear { turning = true }
            .accessibilityElement(children: .combine)
        }
    }
}
#endif
