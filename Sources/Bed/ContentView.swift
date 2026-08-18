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
        player.onItemFailed = { [weak self] reason in
            self?.status = .error(reason)
        }
    }

    func playTapped() {
        if player.isPlaying {
            player.pause()
            status = .paused
            return
        }

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
    }

    func skipTapped() {
        switch mode {
        case .stations:
            stationIndex = (stationIndex + 1) % Stations.all.count
            tune(to: station)
        case .ai:
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                status = .error("Paste a token from replicate.com/account/api-tokens")
                return
            }
            if trimmed.isEmpty {
                status = .error("Say what you want to hear")
                return
            }
            Task { await generateAndPlay(prompt: trimmed) }
        }
    }

    private func playAI() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = .error("Paste a token from replicate.com/account/api-tokens")
            return
        }

        if trimmed.isEmpty {
            status = .error("Say what you want to hear")
            return
        }

        if player.hasItem, lastGeneratedPrompt == trimmed, tunedStationURL == nil {
            player.play()
            status = .playing
            return
        }

        Task { await generateAndPlay(prompt: trimmed) }
    }

    private func tune(to station: Station) {
        lastGeneratedPrompt = nil
        tunedStationURL = station.streamURL
        player.load(url: station.streamURL)
        status = .playing
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
            }
        } catch is CancellationError {
            status = .idle
        } catch {
            if mode == .ai {
                status = .error(error.localizedDescription)
            }
        }

        isGenerating = false
    }
}

struct ContentView: View {
    @StateObject private var model = BedModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var snowUntil: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion && model.status != .making)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let frame = model.player.meter.display(
                playing: model.player.isPlaying,
                seed: model.station.name.hashValue,
                time: now
            )
            radio(now: now, frame: frame, date: context.date)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .background { ChassisBackdrop() }
        .preferredColorScheme(.dark)
        .onChange(of: model.station.name) { _, _ in
            snowUntil = Date().addingTimeInterval(reduceMotion ? 0 : 0.2)
        }
        .onChange(of: model.mode) { _, _ in
            snowUntil = Date().addingTimeInterval(reduceMotion ? 0 : 0.12)
        }
    }

    private func radio(now: TimeInterval, frame: SpectrumFrame, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
            screen(now: now, frame: frame, date: date)
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

    private func screen(now: TimeInterval, frame: SpectrumFrame, date: Date) -> some View {
        let snow: Double = {
            guard let snowUntil else { return 0 }
            let remaining = snowUntil.timeIntervalSince(date)
            return max(0, min(1, remaining / 0.2))
        }()

        return LCDPanel(lit: model.player.isPlaying || model.status == .making, snow: snow) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(model.player.isPlaying ? "ON" : (model.status == .making ? "REC" : "STBY"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(model.player.isPlaying ? BedPalette.phosphor : BedPalette.phosphorDim)
                    Text(String(format: "%d/%d", model.stationIndex + 1, Stations.all.count))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(BedPalette.phosphorDim)
                        .opacity(model.mode == .stations ? 1 : 0)
                        .accessibilityHidden(model.mode != .stations)
                    Spacer()
                    Text(lcdClock)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(BedPalette.phosphor.opacity(0.55))
                }

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
                .padding(.top, 10)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: model.mode)

                SpectrumView(
                    frame: frame,
                    composing: model.status == .making,
                    time: now,
                    reduceMotion: reduceMotion
                )
                .padding(.top, 10)

                Text(model.status.line.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
    }

    private func transport() -> some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: model.playTapped) {
                HStack(spacing: 7) {
                    Image(systemName: model.player.isPlaying ? "pause.fill" : "play.fill")
                        .offset(x: model.player.isPlaying ? 0 : 0.5)
                    Text(model.player.isPlaying ? "Pause" : "Play")
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .contentShape(Capsule())
            }
            .buttonStyle(ChromeButtonStyle(shape: .capsule))
            .disabled(model.isGenerating && model.mode == .ai)
            .accessibilityLabel(model.player.isPlaying ? "Pause" : "Play")

            Button(action: model.skipTapped) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(ChromeButtonStyle(shape: .circle))
            .disabled(model.isGenerating && model.mode == .ai)
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
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(BedPalette.phosphor.opacity(0.55))
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

    private var lcdClock: String {
        switch model.status {
        case .playing: return "► LIVE"
        case .paused: return "❚❚"
        case .making: return "•••"
        case .error: return "ERR"
        case .idle: return "00:00"
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .error: return BedPalette.amber
        case .playing, .making: return BedPalette.phosphor.opacity(0.8)
        default: return BedPalette.phosphorDim
        }
    }
}

