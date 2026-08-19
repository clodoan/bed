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

    static let nts = Source(
        id: "nts",
        name: "NTS",
        blurb: "Independent radio from London.",
        homeURL: URL(string: "https://www.nts.live")!,
        supportURL: URL(string: "https://www.nts.live/supporters")!,
        supportLabel: "Support"
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
    private static let catalogVersion = 2
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
            name: "Poolside",
            vibe: "balearic, boogie, lounge",
            streamURL: URL(string: "https://stream-mixtape-geo.ntslive.net/mixtape4")!,
            source: Sources.nts
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
