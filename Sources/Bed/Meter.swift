import Accelerate
@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import MediaToolbox
import QuartzCore

struct SpectrumFrame: Equatable {
    var bands: [Float]
    var peaks: [Float]
    var wave: [Float]
    var rms: Float
    var live: Bool

    var hasEnergy: Bool {
        rms > 0.012 || bands.contains(where: { $0 > 0.02 })
    }

    static let empty = SpectrumFrame(
        bands: Array(repeating: 0, count: AnalyzerCore.bandCount),
        peaks: Array(repeating: 0, count: AnalyzerCore.bandCount),
        wave: Array(repeating: 0, count: AnalyzerCore.waveCount),
        rms: 0,
        live: false
    )
}

@MainActor
final class AudioMeter: ObservableObject {
    fileprivate let core = AnalyzerCore()
    private var tap: MTAudioProcessingTap?
    private var attachTask: Task<Void, Never>?

    func reset() {
        attachTask?.cancel()
        attachTask = nil
        tap = nil
        core.reset()
    }

    func attach(to item: AVPlayerItem) {
        attachTask?.cancel()
        attachTask = Task { [weak self] in
            await self?.installWhenReady(on: item)
        }
    }

    func display(playing: Bool, seed: Int, time: TimeInterval) -> SpectrumFrame {
        let captured = core.snapshot()
        if captured.live, captured.hasEnergy {
            return captured
        }
        if !playing {
            return captured.hasEnergy ? captured : .empty
        }
        return Self.procedural(seed: seed, time: time, falling: captured)
    }

    private func installWhenReady(on item: AVPlayerItem) async {
        for _ in 0..<40 {
            if Task.isCancelled { return }
            if item.status == .failed { return }
            if item.status == .readyToPlay { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        if Task.isCancelled { return }

        let playerTracks = item.tracks.compactMap { $0.assetTrack }.filter { $0.mediaType == .audio }
        if let track = playerTracks.first {
            install(on: item, track: track)
            return
        }

        let tracks = (try? await item.asset.loadTracks(withMediaType: .audio)) ?? []
        if Task.isCancelled { return }
        guard let track = tracks.first else { return }
        install(on: item, track: track)
    }

    private func install(on item: AVPlayerItem, track: AVAssetTrack) {
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passUnretained(core).toOpaque(),
            init: meterTapInit,
            finalize: meterTapFinalize,
            prepare: meterTapPrepare,
            unprepare: nil,
            process: meterTapProcess
        )

        var created: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &created
        )
        guard status == noErr, let created else { return }

        let parameters = AVMutableAudioMixInputParameters(track: track)
        parameters.audioTapProcessor = created
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        item.audioMix = mix
        tap = created
    }

    private static func procedural(seed: Int, time: TimeInterval, falling: SpectrumFrame) -> SpectrumFrame {
        var bands = [Float](repeating: 0, count: AnalyzerCore.bandCount)
        var wave = [Float](repeating: 0, count: AnalyzerCore.waveCount)
        let drift = Double((seed & 0xFF) + 3) * 0.037

        let kick = pow(max(0, sin(time * (2.05 + drift))), 10)
        for i in 0..<AnalyzerCore.bandCount {
            let phase = Double(i) * 0.73 + Double(seed % 11) * 0.17
            let pulse = 0.5 + 0.5 * sin(time * (1.55 + Double(i) * 0.37) + phase)
            let chatter = 0.5 + 0.5 * sin(time * (5.1 + Double(i) * 0.84) + phase * 1.7)
            let falloff = exp(-Double(i) * 0.085)
            let thump = i < 3 ? kick * (0.72 - Double(i) * 0.18) : kick * 0.04
            let value = min(1, (0.08 + 0.42 * pulse + 0.28 * chatter) * falloff + thump)
            bands[i] = max(Float(value), falling.bands.indices.contains(i) ? falling.bands[i] * 0.55 : 0)
        }

        for i in 0..<AnalyzerCore.waveCount {
            let x = Double(i) / Double(max(1, AnalyzerCore.waveCount - 1))
            wave[i] = Float(sin(x * .pi * 2 + time * (2.15 + drift)) * 0.42)
        }

        var peaks = bands
        for i in peaks.indices where falling.peaks.indices.contains(i) {
            peaks[i] = max(bands[i], falling.peaks[i] - 0.012)
        }

        let rms = bands.reduce(0, +) / Float(bands.count)
        return SpectrumFrame(bands: bands, peaks: peaks, wave: wave, rms: rms, live: false)
    }
}

final class AnalyzerCore: @unchecked Sendable {
    static let bandCount = 16
    static let waveCount = 48
    private static let fftSize = 1024

    private let lock = NSLock()
    private var format = AudioStreamBasicDescription()
    private var bands = [Float](repeating: 0, count: bandCount)
    private var peaks = [Float](repeating: 0, count: bandCount)
    private var wave = [Float](repeating: 0, count: waveCount)
    private var rms: Float = 0
    private var live = false
    private var lastInput = 0.0
    private var agc: Float = 0.08

    private var window = [Float](repeating: 0, count: fftSize)
    private var input = [Float](repeating: 0, count: fftSize)
    private var filled = 0
    private var real = [Float](repeating: 0, count: fftSize / 2)
    private var imag = [Float](repeating: 0, count: fftSize / 2)
    private var magnitudes = [Float](repeating: 0, count: fftSize / 2)
    private var mono = [Float]()
    private let setup: FFTSetup

    init() {
        let log2n = vDSP_Length(log2(Float(Self.fftSize)))
        setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        vDSP_hann_window(&window, vDSP_Length(Self.fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
    }

    func reset() {
        lock.lock()
        bands = Array(repeating: 0, count: Self.bandCount)
        peaks = Array(repeating: 0, count: Self.bandCount)
        wave = Array(repeating: 0, count: Self.waveCount)
        rms = 0
        live = false
        filled = 0
        lastInput = 0
        agc = 0.08
        lock.unlock()
    }

    func prepare(format: AudioStreamBasicDescription, maxFrames: Int) {
        lock.lock()
        self.format = format
        mono = [Float](repeating: 0, count: max(maxFrames, 1))
        lock.unlock()
    }

    func analyze(_ bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) {
        guard frameCount > 0 else { return }
        lock.lock()
        let asbd = format
        if mono.count < frameCount {
            mono = [Float](repeating: 0, count: frameCount)
        }
        let copied = mixMono(bufferList, frameCount: frameCount, format: asbd, into: &mono)
        lock.unlock()
        guard copied > 0 else { return }
        consume(frames: copied)
    }

    func snapshot() -> SpectrumFrame {
        lock.lock()
        defer { lock.unlock() }

        let now = CACurrentMediaTime()
        if now - lastInput > 0.045 {
            let steps = min(12, Int((now - lastInput) / 0.033))
            if steps > 0 {
                for _ in 0..<steps {
                    for i in bands.indices {
                        bands[i] *= 0.76
                        peaks[i] = max(0, peaks[i] - 0.018)
                    }
                    rms *= 0.76
                    for i in wave.indices { wave[i] *= 0.82 }
                }
                lastInput += Double(steps) * 0.033
            }
            if bands.allSatisfy({ $0 < 0.01 }) {
                live = false
            }
        }

        return SpectrumFrame(bands: bands, peaks: peaks, wave: wave, rms: rms, live: live)
    }

    private func consume(frames: Int) {
        lock.lock()
        defer { lock.unlock() }

        var energy: Float = 0
        vDSP_measqv(mono, 1, &energy, vDSP_Length(frames))
        let sampleRMS = sqrt(energy)
        rms = max(sampleRMS * 2.4, rms * 0.72)

        let step = max(1, frames / Self.waveCount)
        var nextWave = [Float](repeating: 0, count: Self.waveCount)
        for i in 0..<Self.waveCount {
            let index = min(frames - 1, i * step)
            let sample = max(-1, min(1, mono[index]))
            nextWave[i] = sample * 0.82 + wave[i] * 0.18
        }
        wave = nextWave

        var offset = 0
        while offset < frames {
            let room = Self.fftSize - filled
            let take = min(room, frames - offset)
            input.replaceSubrange(filled..<(filled + take), with: mono[offset..<(offset + take)])
            filled += take
            offset += take
            if filled == Self.fftSize {
                runFFT()
                filled = Self.fftSize / 2
                input.replaceSubrange(0..<filled, with: input[(Self.fftSize / 2)..<Self.fftSize])
            }
        }

        lastInput = CACurrentMediaTime()
        if rms > 0.008 { live = true }
    }

    private func runFFT() {
        var windowed = [Float](repeating: 0, count: Self.fftSize)
        vDSP_vmul(input, 1, window, 1, &windowed, 1, vDSP_Length(Self.fftSize))

        real.withUnsafeMutableBufferPointer { realp in
            imag.withUnsafeMutableBufferPointer { imagp in
                var split = DSPSplitComplex(realp: realp.baseAddress!, imagp: imagp.baseAddress!)
                windowed.withUnsafeMutableBufferPointer { src in
                    src.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: Self.fftSize / 2) { complex in
                        vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(Self.fftSize / 2))
                    }
                }
                let log2n = vDSP_Length(log2(Float(Self.fftSize)))
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(Self.fftSize / 2))
            }
        }

        let nyquist = max(2, Self.fftSize / 2 - 1)
        var raw = [Float](repeating: 0, count: Self.bandCount)
        for band in 0..<Self.bandCount {
            let lower = exp(log(1.0) + (log(Double(nyquist)) - log(1.0)) * Double(band) / Double(Self.bandCount))
            let upper = exp(log(1.0) + (log(Double(nyquist)) - log(1.0)) * Double(band + 1) / Double(Self.bandCount))
            let start = max(1, Int(lower))
            let end = min(nyquist, max(start + 1, Int(upper)))
            var peak: Float = 0
            for bin in start..<end { peak = max(peak, magnitudes[bin]) }
            raw[band] = sqrt(max(peak, 0))
        }

        let framePeak = max(raw.max() ?? 0, 1e-6)
        agc = max(framePeak, agc * 0.94)
        for band in 0..<Self.bandCount {
            let normalized = min(1, raw[band] / agc)
            let contrast = pow(normalized, 1.25)
            bands[band] = max(contrast, bands[band] * 0.6)
            peaks[band] = max(bands[band], peaks[band] - 0.014)
        }
    }

    private func mixMono(
        _ bufferList: UnsafeMutablePointer<AudioBufferList>,
        frameCount: Int,
        format: AudioStreamBasicDescription,
        into output: inout [Float]
    ) -> Int {
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        guard let first = buffers.first, let data = first.mData else { return 0 }
        let channels = max(1, Int(format.mChannelsPerFrame))
        let isFloat = format.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let interleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0

        if isFloat {
            if !interleaved {
                let firstChannel = data.assumingMemoryBound(to: Float.self)
                if buffers.count > 1, let second = buffers[1].mData {
                    let other = second.assumingMemoryBound(to: Float.self)
                    for i in 0..<frameCount {
                        output[i] = (firstChannel[i] + other[i]) * 0.5
                    }
                } else {
                    output.replaceSubrange(0..<frameCount, with: UnsafeBufferPointer(start: firstChannel, count: frameCount))
                }
                return frameCount
            }
            let samples = data.assumingMemoryBound(to: Float.self)
            for i in 0..<frameCount {
                var sum: Float = 0
                for channel in 0..<channels {
                    sum += samples[i * channels + channel]
                }
                output[i] = sum / Float(channels)
            }
            return frameCount
        }

        if format.mBitsPerChannel == 16 {
            let samples = data.assumingMemoryBound(to: Int16.self)
            let stride = interleaved ? channels : 1
            for i in 0..<frameCount {
                output[i] = Float(samples[i * stride]) / Float(Int16.max)
            }
            return frameCount
        }

        return 0
    }
}

private func meterTapInit(
    _ tap: MTAudioProcessingTap,
    _ clientInfo: UnsafeMutableRawPointer?,
    _ tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    tapStorageOut.pointee = clientInfo
}

private func meterTapFinalize(_ tap: MTAudioProcessingTap) {}

private func meterTapPrepare(
    _ tap: MTAudioProcessingTap,
    _ maxFrames: CMItemCount,
    _ processingFormat: UnsafePointer<AudioStreamBasicDescription>
) {
    let core = Unmanaged<AnalyzerCore>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    core.prepare(format: processingFormat.pointee, maxFrames: Int(maxFrames))
}

private func meterTapProcess(
    _ tap: MTAudioProcessingTap,
    _ numberFrames: CMItemCount,
    _ flags: MTAudioProcessingTapFlags,
    _ bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    _ numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    _ flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    var timeRange = CMTimeRange.zero
    let status = MTAudioProcessingTapGetSourceAudio(
        tap,
        numberFrames,
        bufferListInOut,
        flagsOut,
        &timeRange,
        numberFramesOut
    )
    guard status == noErr else { return }
    let core = Unmanaged<AnalyzerCore>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    core.analyze(bufferListInOut, frameCount: Int(numberFramesOut.pointee))
}
