import Foundation

enum WikipediaLinkCatalog {
    private static let explicitURLs: [String: String] = [
        "Sun": "https://en.wikipedia.org/wiki/Sun",
        "Moon": "https://en.wikipedia.org/wiki/Moon",
        "Earth": "https://en.wikipedia.org/wiki/Earth",
        "Asteroid Belt": "https://en.wikipedia.org/wiki/Asteroid_belt",
        "Kuiper Belt": "https://en.wikipedia.org/wiki/Kuiper_belt",
        "Oort Cloud": "https://en.wikipedia.org/wiki/Oort_cloud",
        "1P/Halley": "https://en.wikipedia.org/wiki/Halley%27s_Comet",
        "2P/Encke": "https://en.wikipedia.org/wiki/Comet_Encke",
        "67P/Churyumov-Gerasimenko": "https://en.wikipedia.org/wiki/67P/Churyumov%E2%80%93Gerasimenko",
        "109P/Swift-Tuttle": "https://en.wikipedia.org/wiki/Comet_Swift%E2%80%93Tuttle",
        "C/1995 O1 Hale-Bopp": "https://en.wikipedia.org/wiki/Comet_Hale%E2%80%93Bopp",
        "C/1996 B2 Hyakutake": "https://en.wikipedia.org/wiki/Comet_Hyakutake",
        "C/2020 F3 NEOWISE": "https://en.wikipedia.org/wiki/C/2020_F3_(NEOWISE)",
        "C/2006 P1 McNaught": "https://en.wikipedia.org/wiki/Comet_McNaught",
        "4 Vesta": "https://en.wikipedia.org/wiki/4_Vesta",
        "2 Pallas": "https://en.wikipedia.org/wiki/2_Pallas",
        "10 Hygiea": "https://en.wikipedia.org/wiki/10_Hygiea",
        "433 Eros": "https://en.wikipedia.org/wiki/433_Eros",
        "101955 Bennu": "https://en.wikipedia.org/wiki/101955_Bennu",
        "162173 Ryugu": "https://en.wikipedia.org/wiki/162173_Ryugu",
        "25143 Itokawa": "https://en.wikipedia.org/wiki/25143_Itokawa",
        "99942 Apophis": "https://en.wikipedia.org/wiki/99942_Apophis"
    ]

    static func urlString(for objectName: String) -> String? {
        if let explicitURL = explicitURLs[objectName] {
            return explicitURL
        }

        let slug = objectName
            .replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)

        guard let slug else { return nil }
        return "https://en.wikipedia.org/wiki/\(slug)"
    }
}
