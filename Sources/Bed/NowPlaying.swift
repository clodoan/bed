import AppKit
import MediaPlayer

@MainActor
final class NowPlaying: NSObject {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onToggle: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?

    private var bound = false

    func bind() {
        guard !bound else { return }
        bound = true

        let remote = MPRemoteCommandCenter.shared()
        remote.playCommand.isEnabled = true
        remote.pauseCommand.isEnabled = true
        remote.stopCommand.isEnabled = true
        remote.togglePlayPauseCommand.isEnabled = true
        remote.nextTrackCommand.isEnabled = true
        remote.previousTrackCommand.isEnabled = true
        remote.skipForwardCommand.isEnabled = false
        remote.skipBackwardCommand.isEnabled = false
        remote.changePlaybackPositionCommand.isEnabled = false
        remote.changePlaybackRateCommand.isEnabled = false

        remote.playCommand.addTarget(self, action: #selector(handlePlay(_:)))
        remote.pauseCommand.addTarget(self, action: #selector(handlePause(_:)))
        remote.stopCommand.addTarget(self, action: #selector(handlePause(_:)))
        remote.togglePlayPauseCommand.addTarget(self, action: #selector(handleToggle(_:)))
        remote.nextTrackCommand.addTarget(self, action: #selector(handleNext(_:)))
        remote.previousTrackCommand.addTarget(self, action: #selector(handlePrevious(_:)))
    }

    func update(
        title: String,
        artist: String,
        subtitle: String,
        isPlaying: Bool,
        isLive: Bool,
        duration: TimeInterval? = nil,
        elapsed: TimeInterval? = nil
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: subtitle,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: isLive,
        ]
        if let duration, duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let elapsed, elapsed.isFinite {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, elapsed)
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = nil
        center.playbackState = .stopped
    }

    private var artwork: MPMediaItemArtwork? {
        let image = NSImage(named: "AppIcon") ?? PixelAsset.nsImage("AppIcon")
        guard let image else { return nil }
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    @objc nonisolated private func handlePlay(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        run { $0.onPlay?() }
    }

    @objc nonisolated private func handlePause(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        run { $0.onPause?() }
    }

    @objc nonisolated private func handleToggle(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        run { $0.onToggle?() }
    }

    @objc nonisolated private func handleNext(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        run { $0.onNext?() }
    }

    @objc nonisolated private func handlePrevious(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        run { $0.onPrevious?() }
    }

    nonisolated private func run(_ work: @escaping @MainActor (NowPlaying) -> Void) -> MPRemoteCommandHandlerStatus {
        Task { @MainActor in
            work(self)
        }
        return .success
    }
}
