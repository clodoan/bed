import Combine
import SwiftUI

@MainActor
final class BedModel: ObservableObject {
    enum Mode: String, CaseIterable {
        case stations
        case ai
    }

    @Published var prompt = ""
    @Published var token: String {
        didSet { UserDefaults.standard.set(token, forKey: "replicateToken") }
    }
    @Published var mode: Mode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "mode")
            if !isGenerating {
                status = player.isPlaying ? .playing : (player.hasItem ? .paused : .idle)
            }
            refreshNowPlaying()
        }
    }
    @Published private(set) var stationIndex: Int {
        didSet { UserDefaults.standard.set(stationIndex, forKey: "stationIndex") }
    }
    @Published var status: Status = .idle
    @Published var isGenerating = false

    var station: Station { Stations.all[stationIndex] }

    var currentSource: Source {
        switch mode {
        case .stations: return station.source
        case .ai: return Sources.replicate
        }
    }

    let player = Player()
    private let nowPlaying = NowPlaying()
    private let generator = Generator()
    private var lastGeneratedPrompt: String?
    private var tunedStationURL: URL?
    private var cancellables = Set<AnyCancellable>()

    enum Status: Equatable {
        case idle
        case making
        case playing
        case paused
        case error(String)

        var line: String {
            switch self {
            case .idle: return "idle"
            case .making: return "making a bed…"
            case .playing: return "playing"
            case .paused: return "paused"
            case .error(let message): return message
            }
        }
    }

    init() {
        token = UserDefaults.standard.string(forKey: "replicateToken") ?? ""
        mode = Mode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "") ?? .stations
        let savedIndex = UserDefaults.standard.integer(forKey: "stationIndex")
        stationIndex = Stations.all.indices.contains(savedIndex) ? savedIndex : 0
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
        guard !aiBusy else { return }
        switch mode {
        case .stations:
            if player.hasItem, tunedStationURL == station.streamURL {
                player.play()
                status = .playing
            } else {
                tune(to: station)
            }
        case .ai:
            playAI()
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
        guard !aiBusy else { return }
        switch mode {
        case .stations:
            stationIndex = (stationIndex + 1) % Stations.all.count
            tune(to: station)
        case .ai:
            guard let prompt = validatedAIPrompt() else { return }
            Task { await generateAndPlay(prompt: prompt) }
        }
    }

    func previousTapped() {
        guard !aiBusy else { return }
        switch mode {
        case .stations:
            stationIndex = (stationIndex + Stations.all.count - 1) % Stations.all.count
            tune(to: station)
        case .ai:
            guard player.hasItem else { return }
            player.seekToStart()
            player.play()
            status = .playing
            refreshNowPlaying()
        }
    }

    private var aiBusy: Bool {
        isGenerating && mode == .ai
    }

    private func playAI() {
        guard let prompt = validatedAIPrompt() else { return }
        if player.hasItem, lastGeneratedPrompt == prompt, tunedStationURL == nil {
            player.play()
            status = .playing
            return
        }
        Task { await generateAndPlay(prompt: prompt) }
    }

    private func validatedAIPrompt() -> String? {
        if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = .error("Paste a token from replicate.com/account/api-tokens")
            return nil
        }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            status = .error("Say what you want to hear")
            return nil
        }
        return trimmed
    }

    private func tune(to station: Station) {
        lastGeneratedPrompt = nil
        tunedStationURL = station.streamURL
        player.load(url: station.streamURL)
        status = .playing
        refreshNowPlaying()
    }

    private func generateAndPlay(prompt: String) async {
        isGenerating = true
        status = .making
        player.pause()

        do {
            let url = try await generator.generate(prompt: prompt, token: token)
            if mode == .ai {
                lastGeneratedPrompt = prompt
                tunedStationURL = nil
                player.load(url: url)
                status = .playing
                refreshNowPlaying()
            }
        } catch is CancellationError {
            status = .idle
        } catch {
            if mode == .ai {
                status = .error(error.localizedDescription)
            }
        }

        isGenerating = false
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
        case .idle:
            if !player.hasItem {
                nowPlaying.clear()
                return
            }
        case .error:
            if !player.hasItem {
                nowPlaying.clear()
                return
            }
        case .making, .playing, .paused:
            break
        }

        switch mode {
        case .stations:
            nowPlaying.update(
                title: station.name,
                artist: station.source.name,
                subtitle: station.vibe,
                isPlaying: player.isPlaying,
                isLive: true
            )
        case .ai:
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            nowPlaying.update(
                title: trimmed.isEmpty ? "AI bed" : trimmed,
                artist: Sources.replicate.name,
                subtitle: status == .making ? "making a bed…" : "instrumental",
                isPlaying: player.isPlaying,
                isLive: false,
                duration: player.duration,
                elapsed: player.elapsed
            )
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: BedModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        .background { ChassisBackdrop() }
        .preferredColorScheme(.dark)
        .onChange(of: model.station.name) { _, _ in
            flashSnow(reduceMotion ? 0 : 0.2)
        }
        .onChange(of: model.mode) { _, _ in
            flashSnow(reduceMotion ? 0 : 0.12)
        }
    }

    private func radio(date: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
            screen(date: date)
                .padding(.top, 14)
            transport()
                .padding(.top, 16)
            SourceFooter(sources: Sources.catalog, current: model.currentSource)
                .padding(.top, 12)
        }
    }

    private func header() -> some View {
        HStack(spacing: 8) {
            Text("🛏️")
                .font(.system(size: 15))
                .accessibilityLabel("Bed")

            Spacer()

            HStack(spacing: 4) {
                ModeTab("Stations", selected: model.mode == .stations) {
                    model.mode = .stations
                }
                ModeTab("AI", selected: model.mode == .ai) {
                    model.mode = .ai
                }
            }
        }
    }

    private func screen(date: Date) -> some View {
        let snow: Double = {
            guard let snowUntil else { return 0 }
            let remaining = snowUntil.timeIntervalSince(date)
            return max(0, min(1, remaining / 0.2))
        }()

        return LCDPanel(lit: model.player.isPlaying || model.status == .making, snow: snow) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(lcdPower)
                        .font(PixelFont.ui(7))
                        .foregroundStyle(model.player.isPlaying ? BedPalette.mint : BedPalette.creamDim)
                    Text(String(format: "%d/%d", model.stationIndex + 1, Stations.all.count))
                        .font(PixelFont.ui(7))
                        .foregroundStyle(BedPalette.creamDim)
                        .opacity(model.mode == .stations ? 1 : 0)
                        .accessibilityHidden(model.mode != .stations)
                    Spacer()
                    Text(lcdClock)
                        .font(PixelFont.ui(7))
                        .foregroundStyle(BedPalette.star.opacity(0.8))
                }

                DancerView(
                    playing: model.player.isPlaying,
                    making: model.status == .making,
                    reduceMotion: reduceMotion
                )
                .padding(.top, 6)

                ZStack(alignment: .topLeading) {
                    stationReadout
                        .opacity(model.mode == .stations ? 1 : 0)
                        .accessibilityHidden(model.mode != .stations)
                    aiReadout
                        .opacity(model.mode == .ai ? 1 : 0)
                        .allowsHitTesting(model.mode == .ai)
                        .accessibilityHidden(model.mode != .ai)
                }
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
                .padding(.top, 8)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: model.mode)

                Text(model.status.line.uppercased())
                    .font(PixelFont.ui(7))
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
    }

    private func transport() -> some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: model.previousTapped) {
                Text("<<")
                    .frame(width: 36, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ChromeButtonStyle(shape: .circle))
            .disabled(aiBusy)
            .accessibilityLabel(model.mode == .stations ? "Previous station" : "Restart track")

            Button(action: model.playTapped) {
                Text(model.player.isPlaying ? "PAUSE" : "PLAY")
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ChromeButtonStyle(shape: .capsule, isOn: model.player.isPlaying))
            .disabled(aiBusy)
            .accessibilityLabel(model.player.isPlaying ? "Pause" : "Play")

            Button(action: model.skipTapped) {
                Text(">>")
                    .frame(width: 36, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ChromeButtonStyle(shape: .circle))
            .disabled(aiBusy)
            .accessibilityLabel(model.mode == .stations ? "Next station" : "Generate again")
        }
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
    }

    private var aiReadout: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(
                "",
                text: $model.prompt,
                prompt: Text("deep work, no vocals, piano")
                    .foregroundStyle(BedPalette.phosphorDim)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(BedPalette.phosphor)
            .tint(BedPalette.phosphor)
            .disabled(model.isGenerating)
            .frame(height: 20, alignment: .leading)
            TextField(
                "",
                text: $model.token,
                prompt: Text("r8_… replicate token")
                    .foregroundStyle(BedPalette.phosphorDim)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(BedPalette.phosphor.opacity(0.55))
            .tint(BedPalette.phosphor)
            .padding(.top, 3)
            .frame(height: 16, alignment: .leading)
            .accessibilityLabel("Replicate token")
        }
    }

    private var aiBusy: Bool {
        model.isGenerating && model.mode == .ai
    }

    private var lcdPower: String {
        if model.player.isPlaying { return "ON" }
        if model.status == .making { return "REC" }
        return "STBY"
    }

    private var lcdClock: String {
        switch model.status {
        case .playing: return "LIVE"
        case .paused: return "HOLD"
        case .making: return "..."
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
        case .playing, .making: return BedPalette.mint
        default: return BedPalette.creamDim
        }
    }
}

