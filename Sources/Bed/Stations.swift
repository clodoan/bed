import Foundation

struct Source: Equatable, Identifiable {
    let id: String
    let name: String
    let blurb: String
    let homeURL: URL
    let supportURL: URL?
    let supportLabel: String
}

enum Sources {
    static let radioParadise = Source(
        id: "radioparadise",
        name: "Radio Paradise",
        blurb: "Listener-supported, commercial-free radio.",
        homeURL: URL(string: "https://radioparadise.com")!,
        supportURL: URL(string: "https://radioparadise.com/donate")!,
        supportLabel: "Donate"
    )

    static let chilltrax = Source(
        id: "chilltrax",
        name: "Chilltrax",
        blurb: "Listener-supported chillout radio.",
        homeURL: URL(string: "https://www.chilltrax.com")!,
        supportURL: URL(string: "https://www.chilltrax.com")!,
        supportLabel: "Donate"
    )

    static let nts = Source(
        id: "nts",
        name: "NTS",
        blurb: "Independent radio from London.",
        homeURL: URL(string: "https://www.nts.live")!,
        supportURL: URL(string: "https://www.nts.live/supporters")!,
        supportLabel: "Support"
    )

    static let dogglounge = Source(
        id: "dogglounge",
        name: "Dogglounge",
        blurb: "Independent deep house radio since 2003.",
        homeURL: URL(string: "https://dogglounge.com")!,
        supportURL: nil,
        supportLabel: "Open"
    )

    static let islaNegra = Source(
        id: "islanegra",
        name: "Isla Negra",
        blurb: "Listener-supported downtempo from Chile.",
        homeURL: URL(string: "https://www.radioislanegra.com")!,
        supportURL: URL(string: "https://www.radioislanegra.com")!,
        supportLabel: "Donate"
    )

    static let asip = Source(
        id: "9128",
        name: "9128",
        blurb: "Ambient radio from the ASIP label.",
        homeURL: URL(string: "https://9128.live")!,
        supportURL: URL(string: "https://9128.live/guestbook/donate")!,
        supportLabel: "Donate"
    )

    static let nightride = Source(
        id: "nightride",
        name: "Nightride FM",
        blurb: "Independent synthwave radio.",
        homeURL: URL(string: "https://nightride.fm")!,
        supportURL: URL(string: "https://www.patreon.com/nightridefm")!,
        supportLabel: "Patreon"
    )

    static var catalog: [Source] {
        var seen = Set<String>()
        return Stations.all.map(\.source).filter { seen.insert($0.id).inserted }
    }
}

struct Station: Equatable {
    let name: String
    let vibe: String
    let streamURL: URL
    let source: Source
}

enum Stations {
    private static let catalogVersion = 3
    private static let catalogVersionKey = "stationCatalogVersion"
    static let indexDefaultsKey = "stationIndex"

    static let all: [Station] = [
        Station(
            name: "Mellow Mix",
            vibe: "downtempo, mellow, late night",
            streamURL: URL(string: "https://stream.radioparadise.com/mellow-320")!,
            source: Sources.radioParadise
        ),
        Station(
            name: "Chilltrax",
            vibe: "chillout, downtempo, soft house",
            streamURL: URL(string: "https://streamssleu.chilltrax.com/stream")!,
            source: Sources.chilltrax
        ),
        Station(
            name: "Poolside",
            vibe: "balearic, boogie, lounge",
            streamURL: URL(string: "https://stream-mixtape-geo.ntslive.net/mixtape4")!,
            source: Sources.nts
        ),
        Station(
            name: "4 To The Floor",
            vibe: "house, chicago to detroit",
            streamURL: URL(string: "https://stream-mixtape-geo.ntslive.net/mixtape5")!,
            source: Sources.nts
        ),
        Station(
            name: "Slow Focus",
            vibe: "ambient, drone, for work",
            streamURL: URL(string: "https://stream-mixtape-geo.ntslive.net/mixtape")!,
            source: Sources.nts
        ),
        Station(
            name: "Low Key",
            vibe: "quiet hip-hop, late night",
            streamURL: URL(string: "https://stream-mixtape-geo.ntslive.net/mixtape2")!,
            source: Sources.nts
        ),
        Station(
            name: "Dogglounge",
            vibe: "deep house",
            streamURL: URL(string: "https://dogglounge.com:8000/")!,
            source: Sources.dogglounge
        ),
        Station(
            name: "Isla Negra",
            vibe: "downtempo, ambient, chile",
            streamURL: URL(string: "https://radioislanegra.org/radio/8000/basic.aac")!,
            source: Sources.islaNegra
        ),
        Station(
            name: "9128",
            vibe: "ambient, drone, asip",
            streamURL: URL(string: "https://streams.radio.co/s0aa1e6f4a/listen")!,
            source: Sources.asip
        ),
        Station(
            name: "Chillsynth",
            vibe: "chill synth, night drive",
            streamURL: URL(string: "https://stream.nightride.fm/chillsynth.mp3")!,
            source: Sources.nightride
        ),
        Station(
            name: "Nightride",
            vibe: "synthwave",
            streamURL: URL(string: "https://stream.nightride.fm/nightride.mp3")!,
            source: Sources.nightride
        ),
    ]

    static func loadSavedIndex(from defaults: UserDefaults = .standard) -> Int {
        if defaults.integer(forKey: catalogVersionKey) != catalogVersion {
            defaults.set(catalogVersion, forKey: catalogVersionKey)
            return 0
        }
        let saved = defaults.integer(forKey: indexDefaultsKey)
        guard all.indices.contains(saved) else { return 0 }
        return saved
    }
}
