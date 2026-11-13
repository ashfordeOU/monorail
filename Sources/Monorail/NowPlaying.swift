#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// What's playing in Music or Spotify, from the notices they broadcast to every app as the track or state
/// changes: no permission needed to read it, and nothing is polled. The buttons ask the app to play, pause
/// or skip, which macOS asks you to allow once (Monorail only; the App Store's rules keep Signalbox from it).
final class NowPlaying: ObservableObject {
    static let shared = NowPlaying()

    struct Track: Equatable {
        var app: String
        var bundleID: String
        var title: String
        var artist: String
        var album: String
        var playing: Bool
        var duration: Double?
    }

    @Published private(set) var track: Track?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: Notification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main) { [weak self] note in
            self?.read(note.userInfo, app: "Music", bundleID: "com.apple.Music")
        }
        center.addObserver(forName: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] note in
            self?.read(note.userInfo, app: "Spotify", bundleID: "com.spotify.client")
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if app?.bundleIdentifier == self?.track?.bundleID { self?.track = nil }
        }
    }

    private func read(_ info: [AnyHashable: Any]?, app: String, bundleID: String) {
        guard let info else { return }
        let state = (info["Player State"] as? String) ?? ""
        if state == "Stopped" { if track?.bundleID == bundleID { track = nil }; return }
        let title = (info["Name"] as? String) ?? ""
        guard !title.isEmpty else { return }
        let duration = (info["Total Time"] as? NSNumber).map { $0.doubleValue / 1000 } ?? (info["Duration"] as? NSNumber).map { $0.doubleValue / 1000 }
        track = Track(app: app, bundleID: bundleID, title: title, artist: (info["Artist"] as? String) ?? "",
                      album: (info["Album"] as? String) ?? "", playing: state == "Playing", duration: duration)
    }

    var canControl: Bool { !Edition.isAppStore }

    func send(_ command: String) {
        guard canControl, let track else { return }
        let source = "tell application \"\(track.app)\" to \(command)"
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
        if command == "playpause" { self.track?.playing.toggle() }
    }

    /// For the live notch: a playing track, lowest priority, so a call or a timer always wins.
    var activity: NotchActivity? {
        guard let track, track.playing else { return nil }
        let text = track.title.count > 14 ? String(track.title.prefix(13)) + "…" : track.title
        return NotchActivity(.music, symbol: "music.note", text: text, tint: "purple")
    }
}

/// The island's Now Playing row: the track, the app, and play/pause and skip.
struct NowPlayingRow: View {
    @ObservedObject private var now = NowPlaying.shared

    var body: some View {
        if let track = now.track {
            HStack(spacing: 10) {
                if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: track.bundleID) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path)).resizable().frame(width: 34, height: 34)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text([track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
                Spacer(minLength: 6)
                if track.playing { Equaliser().frame(width: 18, height: 14) }
                if now.canControl {
                    HStack(spacing: 14) {
                        Button { now.send("previous track") } label: { Image(systemName: "backward.fill").accessibilityLabel("Previous") }
                        Button { now.send("playpause") } label: {
                            Image(systemName: track.playing ? "pause.fill" : "play.fill").font(.system(size: 15)).accessibilityLabel(track.playing ? "Pause" : "Play")
                        }
                        Button { now.send("next track") } label: { Image(systemName: "forward.fill").accessibilityLabel("Next") }
                    }
                    .buttonStyle(.plain).foregroundStyle(.white).font(.system(size: 12))
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.07)))
        }
    }
}

/// Three bars dancing while music plays.
private struct Equaliser: View {
    @State private var phase = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(Color(nsColor: .systemPurple))
                    .frame(width: 3, height: phase ? [14, 6, 11][i] : [5, 13, 7][i])
                    .animation(Motion.reduced ? nil : .easeInOut(duration: [0.45, 0.35, 0.55][i]).repeatForever(autoreverses: true), value: phase)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .onAppear { phase = true }
        .accessibilityHidden(true)
    }
}
#endif
