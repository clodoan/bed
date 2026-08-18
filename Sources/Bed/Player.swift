import AVFoundation
import Combine
import Foundation

@MainActor
final class Player: ObservableObject {
    @Published private(set) var isPlaying = false

    let meter = AudioMeter()
    var onItemFailed: ((String) -> Void)?

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var failureCancellable: AnyCancellable?

    var hasItem: Bool {
        player?.currentItem != nil
    }

    func load(url: URL) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        player?.pause()
        meter.reset()

        let item = AVPlayerItem(url: url)
        meter.attach(to: item)
        failureCancellable = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] itemStatus in
                guard itemStatus == .failed, let self else { return }
                self.isPlaying = false
                let reason = self.player?.currentItem?.error?.localizedDescription
                self.onItemFailed?(reason ?? "Could not play this stream")
            }
        let av = AVPlayer(playerItem: item)
        av.actionAtItemEnd = .none
        player = av

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.player?.seek(to: .zero)
                self.player?.play()
                self.isPlaying = true
            }
        }

        av.play()
        isPlaying = true
    }

    func play() {
        guard hasItem else { return }
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }
}
