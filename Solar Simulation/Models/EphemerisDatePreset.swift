import Foundation

struct EphemerisDatePreset: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let isoDate: String
    let notes: String

    var displayTitle: String {
        "\(title) - \(isoDate)"
    }
}

enum EphemerisPresetCatalog {
    static let presets: [EphemerisDatePreset] = [
        EphemerisDatePreset(
            id: "halley_1986",
            title: "Halley 1986 Visit",
            isoDate: "1986-02-09",
            notes: "Historic Halley apparition epoch."
        ),
        EphemerisDatePreset(
            id: "j2000",
            title: "J2000 Reference",
            isoDate: "2000-01-01",
            notes: "Useful modern reference epoch. Internally use 12:00 UTC."
        ),
        EphemerisDatePreset(
            id: "modern_2010",
            title: "Modern Solar System 2010",
            isoDate: "2010-01-01",
            notes: "Modern comparison epoch."
        ),
        EphemerisDatePreset(
            id: "modern_2020",
            title: "Modern Solar System 2020",
            isoDate: "2020-01-01",
            notes: "Modern comparison epoch."
        ),
        EphemerisDatePreset(
            id: "eclipse_2024",
            title: "April 2024 Alignment",
            isoDate: "2024-04-08",
            notes: "Useful Earth/Moon/Sun alignment preset."
        ),
        EphemerisDatePreset(
            id: "current_2026",
            title: "Current Project Epoch",
            isoDate: "2026-05-28",
            notes: "Current project reference date."
        ),
        EphemerisDatePreset(
            id: "future_2030",
            title: "Near Future 2030",
            isoDate: "2030-01-01",
            notes: "Near-future comparison epoch."
        ),
        EphemerisDatePreset(
            id: "future_2040",
            title: "Future 2040",
            isoDate: "2040-01-01",
            notes: "Future comparison epoch."
        ),
        EphemerisDatePreset(
            id: "halley_2061",
            title: "Halley 2061 Return Window",
            isoDate: "2061-07-28",
            notes: "Future Halley return window."
        ),
        EphemerisDatePreset(
            id: "future_2100",
            title: "Future 2100",
            isoDate: "2100-01-01",
            notes: "Far-future comparison epoch."
        )
    ]

    static func preset(id: String) -> EphemerisDatePreset? {
        presets.first { $0.id == id }
    }

    static func noonUTCDate(for presetID: String) -> Date? {
        guard let preset = preset(id: presetID) else { return nil }
        return noonUTCDate(isoDate: preset.isoDate)
    }

    static func noonUTCDate(isoDate: String) -> Date? {
        DateFormatters.ephemerisTimestampUTC.date(from: "\(isoDate) 12:00:00")
    }
}
