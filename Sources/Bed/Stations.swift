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
    static let somaFM = Source(
        id: "somafm",
        name: "SomaFM",
        blurb: "Listener-supported, commercial-free radio.",
        homeURL: URL(string: "https://somafm.com")!,
        supportURL: URL(string: "https://somafm.com/support/")!,
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

    static let replicate = Source(
        id: "replicate",
        name: "Replicate",
        blurb: "Stable Audio 2.5 generates the AI beds.",
        homeURL: URL(string: "https://replicate.com/stability-ai/stable-audio-2.5")!,
        supportURL: nil,
        supportLabel: "Visit"
    )

    /// Unique sources in catalog order, then the AI provider.
    static var catalog: [Source] {
        var seen = Set<String>()
        var list: [Source] = []
        for station in Stations.all where seen.insert(station.source.id).inserted {
            list.append(station.source)
        }
        if seen.insert(replicate.id).inserted {
            list.append(replicate)
        }
        return list
    }
}

struct Station: Equatable {
    let name: String
    let vibe: String
    let streamURL: URL
    let source: Source
}

enum Stations {
    static let all: [Station] = [
        Station(
            name: "Beat Blender",
            vibe: "deep house & downtempo",
            streamURL: URL(string: "https://ice2.somafm.com/beatblender-128-mp3")!,
            source: Sources.somaFM
        ),
        Station(
            name: "The Trip",
            vibe: "progressive house & trance",
            streamURL: URL(string: "https://ice2.somafm.com/thetrip-128-mp3")!,
            source: Sources.somaFM
        ),
        Station(
            name: "Groove Salad",
            vibe: "ambient downtempo chill",
            streamURL: URL(string: "https://ice2.somafm.com/groovesalad-256-mp3")!,
            source: Sources.somaFM
        ),
        Station(
            name: "Fluid",
            vibe: "future soul & liquid beats",
            streamURL: URL(string: "https://ice2.somafm.com/fluid-128-mp3")!,
            source: Sources.somaFM
        ),
        Station(
            name: "Illinois Street Lounge",
            vibe: "retro cocktail lounge",
            streamURL: URL(string: "https://ice2.somafm.com/illstreet-128-mp3")!,
            source: Sources.somaFM
        ),
        Station(
            name: "Nightride",
            vibe: "synthwave",
            streamURL: URL(string: "https://stream.nightride.fm/nightride.mp3")!,
            source: Sources.nightride
        ),
    ]
}
