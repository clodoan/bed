import AVFoundation
import Combine
import CoreAudio
import Foundation

@MainActor
final class Player: ObservableObject {
    @Published private(set) var isPlaying = false

    let meter = AudioMeter()
    var onItemFailed: ((String) -> Void)?
    var onRouteLost: (() -> Void)?

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var failureCancellable: AnyCancellable?
    private let routeMonitor = OutputRouteMonitor()

    var hasItem: Bool {
        player?.currentItem != nil
    }

    var elapsed: TimeInterval {
        player?.currentTime().seconds ?? 0
    }

    var duration: TimeInterval? {
        guard let time = player?.currentItem?.duration, time.isNumeric else { return nil }
        let seconds = time.seconds
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }

    init() {
        routeMonitor.onCurrentRouteLost = { [weak self] in
            self?.handleRouteLost()
        }
        routeMonitor.start()
    }

    deinit {
        routeMonitor.stop()
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

    func seekToStart() {
        player?.seek(to: .zero)
    }

    private func handleRouteLost() {
        guard isPlaying else { return }
        pause()
        onRouteLost?()
    }
}

/// Pauses when the current output goes away: wired jack unplug, Bluetooth
/// disconnect, USB/AirPlay device removed. Switching to another still-present
/// output (Control Center, Sound settings) leaves playback running.
final class OutputRouteMonitor: @unchecked Sendable {
    var onCurrentRouteLost: (@MainActor () -> Void)?

    private let queue = DispatchQueue(label: "bed.output-route")
    private var currentDevice: AudioDeviceID = 0
    private var lastDataSource: UInt32?
    private var lastJackConnected: Bool?
    private var defaultListener: AudioObjectPropertyListenerBlock?
    private var deviceListener: AudioObjectPropertyListenerBlock?

    func start() {
        queue.async { [weak self] in
            self?.installDefaultListener()
            self?.attach(to: Self.defaultOutputDevice())
        }
    }

    func stop() {
        queue.sync {
            removeDefaultListener()
            detachDevice()
        }
    }

    private func installDefaultListener() {
        guard defaultListener == nil else { return }
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            self.queue.async {
                self.defaultOutputChanged()
            }
        }
        defaultListener = listener
        var address = Self.defaultOutputAddress
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            queue,
            listener
        )
    }

    private func removeDefaultListener() {
        guard let listener = defaultListener else { return }
        var address = Self.defaultOutputAddress
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            queue,
            listener
        )
        defaultListener = nil
    }

    private func defaultOutputChanged() {
        let previous = currentDevice
        let next = Self.defaultOutputDevice()
        if previous != 0, previous != next, !Self.isAlive(previous) || Self.isHeadphonesLike(previous) {
            notifyRouteLost()
        }
        attach(to: next)
    }

    private func attach(to device: AudioDeviceID) {
        detachDevice()
        currentDevice = device
        lastDataSource = Self.dataSource(device)
        lastJackConnected = Self.jackConnected(device)
        guard device != 0 else { return }

        let listener: AudioObjectPropertyListenerBlock = { [weak self] count, addresses in
            var selectors: [AudioObjectPropertySelector] = []
            selectors.reserveCapacity(Int(count))
            for index in 0..<Int(count) {
                selectors.append(addresses[index].mSelector)
            }
            self?.devicePropertiesChanged(selectors)
        }
        deviceListener = listener
        for var address in [Self.dataSourceAddress, Self.jackAddress, Self.aliveAddress] where
            AudioObjectHasProperty(device, &address)
        {
            AudioObjectAddPropertyListenerBlock(device, &address, queue, listener)
        }
    }

    private func detachDevice() {
        guard let listener = deviceListener, currentDevice != 0 else {
            deviceListener = nil
            currentDevice = 0
            return
        }
        for var address in [Self.dataSourceAddress, Self.jackAddress, Self.aliveAddress] {
            AudioObjectRemovePropertyListenerBlock(currentDevice, &address, queue, listener)
        }
        deviceListener = nil
        currentDevice = 0
        lastDataSource = nil
        lastJackConnected = nil
    }

    private func devicePropertiesChanged(_ selectors: [AudioObjectPropertySelector]) {
        let device = currentDevice
        guard device != 0 else { return }

        var lost = false
        for selector in selectors {
            switch selector {
            case kAudioDevicePropertyDeviceIsAlive:
                if !Self.isAlive(device) { lost = true }
            case kAudioDevicePropertyJackIsConnected:
                let connected = Self.jackConnected(device)
                if lastJackConnected == true, connected == false { lost = true }
                lastJackConnected = connected
            case kAudioDevicePropertyDataSource:
                let source = Self.dataSource(device)
                if lastDataSource == Self.headphonesSource, source != Self.headphonesSource {
                    lost = true
                }
                lastDataSource = source
            default:
                break
            }
        }
        if lost { notifyRouteLost() }
    }

    private func notifyRouteLost() {
        Task { @MainActor in
            onCurrentRouteLost?()
        }
    }

    private static let headphonesSource: UInt32 = 0x6864_706E // 'hdpn'

    private static let defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private static let dataSourceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDataSource,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static let jackAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyJackIsConnected,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static let aliveAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsAlive,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private static func defaultOutputDevice() -> AudioDeviceID {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = defaultOutputAddress
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &device
        )
        return status == noErr ? device : 0
    }

    private static func isAlive(_ device: AudioDeviceID) -> Bool {
        guard device != 0 else { return false }
        var alive: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = aliveAddress
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &alive)
        return status == noErr && alive != 0
    }

    private static func dataSource(_ device: AudioDeviceID) -> UInt32? {
        guard device != 0 else { return nil }
        var source: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = dataSourceAddress
        guard AudioObjectHasProperty(device, &address) else { return nil }
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &source)
        return status == noErr ? source : nil
    }

    private static func jackConnected(_ device: AudioDeviceID) -> Bool? {
        guard device != 0 else { return nil }
        var connected: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = jackAddress
        guard AudioObjectHasProperty(device, &address) else { return nil }
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &connected)
        return status == noErr ? connected != 0 : nil
    }

    private static func isHeadphonesLike(_ device: AudioDeviceID) -> Bool {
        if jackConnected(device) == true { return true }
        if dataSource(device) == headphonesSource { return true }
        switch transportType(device) {
        case kAudioDeviceTransportTypeBluetooth,
             kAudioDeviceTransportTypeBluetoothLE,
             kAudioDeviceTransportTypeAirPlay:
            return true
        default:
            return false
        }
    }

    private static func transportType(_ device: AudioDeviceID) -> UInt32 {
        guard device != 0 else { return 0 }
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &transport)
        return status == noErr ? transport : 0
    }
}
