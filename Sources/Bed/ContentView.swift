import AppKit
import Combine
import SwiftUI

@MainActor
final class BedModel: ObservableObject {
    @Published private(set) var stationIndex: Int {
        didSet { UserDefaults.standard.set(stationIndex, forKey: Stations.indexDefaultsKey) }
    }
    @Published var status: Status = .idle

    var station: Station { Stations.all[stationIndex] }

    let player = Player()
    private let nowPlaying = NowPlaying()
    private var tunedStationURL: URL?
    private var cancellables = Set<AnyCancellable>()

    enum Status: Equatable {
        case idle
        case playing
        case paused
        case error(String)

        var line: String {
            switch self {
            case .idle: return "idle"
            case .playing: return "playing"
            case .paused: return "paused"
            case .error: return "no signal"
            }
        }

        var detail: String {
            switch self {
            case .error(let message): return message
            default: return line
            }
        }
    }

    init() {
        stationIndex = Stations.loadSavedIndex()
        player.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        player.$isPlaying
            .sink { [weak self] playing in
                self?.playbackChanged(playing)
            }
            .store(in: &cancellables)
        player.onItemFailed = { [weak self] reason in
            self?.status = .error(reason)
            self?.refreshNowPlaying()
        }
        player.onRouteLost = { [weak self] in
            self?.status = .paused
            self?.refreshNowPlaying()
        }
        nowPlaying.onPlay = { [weak self] in self?.play() }
        nowPlaying.onPause = { [weak self] in self?.pause() }
        nowPlaying.onToggle = { [weak self] in self?.playTapped() }
        nowPlaying.onNext = { [weak self] in self?.skipTapped() }
        nowPlaying.onPrevious = { [weak self] in self?.previousTapped() }
        nowPlaying.bind()
    }

    func playTapped() {
        if player.isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        if player.hasItem, tunedStationURL == station.streamURL {
            player.play()
            status = .playing
        } else {
            tune(to: station)
        }
        refreshNowPlaying()
    }

    func pause() {
        player.pause()
        if status == .playing {
            status = .paused
        }
        refreshNowPlaying()
    }

    func skipTapped() {
        stationIndex = (stationIndex + 1) % Stations.all.count
        tune(to: station)
    }

    func previousTapped() {
        stationIndex = (stationIndex + Stations.all.count - 1) % Stations.all.count
        tune(to: station)
    }

    private func tune(to station: Station) {
        tunedStationURL = station.streamURL
        player.load(url: station.streamURL)
        status = .playing
        refreshNowPlaying()
    }

    private func playbackChanged(_ playing: Bool) {
        if playing {
            if status == .paused || status == .idle {
                status = .playing
            }
        } else if status == .playing {
            status = .paused
        }
        refreshNowPlaying()
    }

    private func refreshNowPlaying() {
        switch status {
        case .idle, .error:
            if !player.hasItem {
                nowPlaying.clear()
                return
            }
        case .playing, .paused:
            break
        }

        nowPlaying.update(
            title: station.name,
            artist: station.source.name,
            subtitle: station.vibe,
            isPlaying: player.isPlaying,
            isLive: true
        )
    }
}

struct ContentView: View {
    @ObservedObject var model: BedModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("lcdFace") private var face: Face = .dancer
    @State private var snowUntil: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: snowUntil == nil)) { context in
            radio(date: context.date)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .background(BedPalette.night)
        .preferredColorScheme(.dark)
        .onChange(of: model.station.name) { _, _ in
            flashSnow(reduceMotion ? 0 : 0.2)
        }
        .onChange(of: face) { _, _ in
            flashSnow(reduceMotion ? 0 : 0.12)
        }
    }

    private func radio(date: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            screen(date: date)
            HStack(alignment: .center, spacing: 16) {
                SpeakerGrille()
                    .frame(width: 72, height: 72)
                Spacer(minLength: 4)
                transport()
            }
            .padding(.top, 16)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                SourceFooter(sources: Sources.catalog, current: model.station.source)
                Button("QUIT") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(PixelFont.ui(6))
                .foregroundStyle(BedPalette.cream.opacity(0.28))
                .keyboardShortcut("q", modifiers: .command)
                .accessibilityLabel("Quit Bed")
            }
            .padding(.top, 12)
        }
    }

    private func screen(date: Date) -> some View {
        let snow: Double = {
            guard let snowUntil else { return 0 }
            let remaining = snowUntil.timeIntervalSince(date)
            return max(0, min(1, remaining / 0.2))
        }()

        return LCDPanel(
            lit: model.player.isPlaying,
            snow: snow,
            scene: lcdScene
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(lcdPower)
                        .font(PixelFont.ui(7))
                        .foregroundStyle(model.player.isPlaying ? BedPalette.glow : BedPalette.creamDim)
                    Text(String(format: "%d/%d", model.stationIndex + 1, Stations.all.count))
                        .font(PixelFont.ui(7))
                        .foregroundStyle(BedPalette.creamDim)
                    Spacer()
                    FaceToggle(face: $face)
                    Text(lcdClock)
                        .font(PixelFont.ui(7))
                        .foregroundStyle(BedPalette.lamp.opacity(0.85))
                }

                faceStage
                    .padding(.top, 6)

                stationReadout
                    .padding(.top, 8)

                Text(model.status.line.uppercased())
                    .font(PixelFont.ui(7))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: 12, maxHeight: 12, alignment: .leading)
                    .padding(.top, 10)
                    .accessibilityLabel(model.status.detail)
            }
            .shadow(color: .black.opacity(0.8), radius: 0, x: 1, y: 1)
        }
    }

    private func transport() -> some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: model.previousTapped) {
                Text("<<")
            }
            .buttonStyle(TactileButtonStyle(kind: .skip))
            .accessibilityLabel("Previous station")

            Button(action: model.playTapped) {
                Text(model.player.isPlaying ? "||" : "|>")
            }
            .buttonStyle(TactileButtonStyle(kind: .action, lit: model.player.isPlaying))
            .accessibilityLabel(model.player.isPlaying ? "Pause" : "Play")

            Button(action: model.skipTapped) {
                Text(">>")
            }
            .buttonStyle(TactileButtonStyle(kind: .skip))
            .accessibilityLabel("Next station")
        }
    }

    private var lcdScene: LCDScene {
        switch face {
        case .desk:
            return .desk(playing: model.player.isPlaying, reduceMotion: reduceMotion)
        case .dancer:
            return .dancer(playing: model.player.isPlaying, reduceMotion: reduceMotion)
        }
    }

    private var faceStage: some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: 148)
            .accessibilityLabel(face == .dancer
                ? (model.player.isPlaying ? "Character dancing" : "Character idle")
                : "")
            .accessibilityHidden(face != .dancer)
    }

    private var stationReadout: some View {
        VStack(alignment: .leading, spacing: 0) {
            MarqueeText(
                text: model.station.name.uppercased(),
                running: model.player.isPlaying,
                reduceMotion: reduceMotion
            )
            .frame(height: 20, alignment: .leading)
            Text(model.station.vibe)
                .font(PixelFont.ui(6))
                .foregroundStyle(BedPalette.creamDim)
                .lineLimit(1)
                .padding(.top, 3)
                .frame(height: 16, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
    }

    private var lcdPower: String {
        model.player.isPlaying ? "ON" : "STBY"
    }

    private var lcdClock: String {
        switch model.status {
        case .playing: return "LIVE"
        case .paused: return "HOLD"
        case .error: return "ERR"
        case .idle: return "IDLE"
        }
    }

    private func flashSnow(_ duration: TimeInterval) {
        snowUntil = Date().addingTimeInterval(duration)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000) + 20))
            if let snowUntil, snowUntil <= Date() {
                self.snowUntil = nil
            }
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .error: return BedPalette.amber
        case .playing: return BedPalette.glow
        default: return BedPalette.creamDim
        }
    }
}
