import SwiftUI
import Foundation

struct Artwork: Identifiable {
    let id: String               // stable key for persistence
    let fileName: String         // SVG filename without extension
    let displayName: String      // human-readable name shown in UI
    let completionMessage: String
    let month: Int               // 1-12  anchor month
    let day: Int                 // 1-31  anchor day
}

extension Artwork {

    // MARK: - Curated Calendar

    /// 79 artworks ordered chronologically (Jan → Dec).
    /// Each artwork anchors to a specific (month, day) and remains the
    /// daily artwork until the next entry's date arrives.
    /// Placement reflects seasonal imagery, cultural resonance, and the
    /// rhythm of the natural world — without endorsing specific holidays.
    static let catalog: [Artwork] = [

        // ── January — Deep winter, fresh start ──────────────────────

        Artwork(id: "snowyVillage",       fileName: "snowyVillage",       displayName: "Snowy Village",          completionMessage: "Snow makes every rooftop the same height.",                                    month: 1,  day: 1),
        Artwork(id: "polarBearIce",       fileName: "polarBearIce",       displayName: "Polar Bear on Ice",      completionMessage: "The ice holds more weight than it shows.",                                     month: 1,  day: 6),
        Artwork(id: "wolfSnow",           fileName: "wolfSnow",           displayName: "Wolf in Snow",           completionMessage: "The wolf doesn't follow the path. The path follows the wolf.",                 month: 1,  day: 11),
        Artwork(id: "nightTrainStars",    fileName: "nightTrainStars",    displayName: "Night Train",            completionMessage: "The stars don't follow the train. They just stay where they are.",              month: 1,  day: 16),
        Artwork(id: "logCabinSmoke",      fileName: "logCabinSmoke",      displayName: "Log Cabin",              completionMessage: "Smoke rises like a conversation no one needs to finish.",                       month: 1,  day: 21),
        Artwork(id: "northerlights",      fileName: "northerlights",      displayName: "Northern Lights",        completionMessage: "The sky practices its colors when no one is keeping score.",                    month: 1,  day: 26),

        // ── February — Winter continues, introspection ──────────────

        Artwork(id: "cathedral",          fileName: "cathedral",          displayName: "The Cathedral",          completionMessage: "Stone remembers what hands intended.",                                          month: 2,  day: 1),
        Artwork(id: "foxSleepingSnow",    fileName: "foxSleepingSnow",    displayName: "Fox Sleeping in Snow",   completionMessage: "Even the snow knows when to be quiet.",                                        month: 2,  day: 5),
        Artwork(id: "campfireStars",      fileName: "campfireStars",      displayName: "Campfire Under Stars",   completionMessage: "The fire and the stars take turns telling the same story.",                     month: 2,  day: 10),
        Artwork(id: "windowsillBottles",  fileName: "windowsillBottles",  displayName: "Windowsill Bottles",     completionMessage: "Light passes through everything it loves.",                                    month: 2,  day: 15),
        Artwork(id: "roseBouquetVase",    fileName: "roseBouquetVase",    displayName: "Rose Bouquet",           completionMessage: "Every petal falls on its own time.",                                            month: 2,  day: 20),
        Artwork(id: "snowyOwl",          fileName: "snowyOwl",          displayName: "Snowy Owl",              completionMessage: "The snow falls quietly, but the owl hears it all.",                            month: 2,  day: 25),

        // ── March — Thaw, awakening ─────────────────────────────────

        Artwork(id: "tabbyCatWindowsill", fileName: "tabbyCatWindowsill", displayName: "Tabby Cat",              completionMessage: "The windowsill is the best seat for watching the world decide.",               month: 3,  day: 1),
        Artwork(id: "heronMoonlitLake",   fileName: "heronMoonlitLake",   displayName: "Heron on Moonlit Lake",  completionMessage: "The lake keeps the heron's reflection longer than the heron stays.",           month: 3,  day: 6),
        Artwork(id: "mistyFjordDawn",     fileName: "mistyFjordDawn",     displayName: "Misty Fjord at Dawn",    completionMessage: "The fjord has been keeping this morning for a long time.",                      month: 3,  day: 11),
        Artwork(id: "floodedDockTwilight",fileName: "floodedDockTwilight",displayName: "Flooded Dock",           completionMessage: "The water doesn't know it's trespassing.",                                    month: 3,  day: 16),
        Artwork(id: "shamrockRainbow",   fileName: "shamrockRainbow",   displayName: "Shamrock Rainbow",       completionMessage: "Luck is just patience dressed in green.",                                      month: 3,  day: 17),
        Artwork(id: "driedFlowerBouquet", fileName: "driedFlowerBouquet", displayName: "Dried Flowers",          completionMessage: "Beauty doesn't leave. It just changes its mind about color.",                  month: 3,  day: 21),
        Artwork(id: "mapleSeeds",         fileName: "mapleSeeds",         displayName: "Maple Seeds",            completionMessage: "Falling is just the first step of going somewhere.",                           month: 3,  day: 26),

        // ── April — Full spring, blossoms ───────────────────────────

        Artwork(id: "hummingbirdGarden",  fileName: "hummingbirdGarden",  displayName: "Hummingbird Garden",     completionMessage: "Speed is just stillness in disguise.",                                         month: 4,  day: 1),
        Artwork(id: "bicycleFlowerBasket",fileName: "bicycleFlowerBasket",displayName: "Bicycle & Flowers",      completionMessage: "Some journeys carry their own garden.",                                        month: 4,  day: 6),
        Artwork(id: "koi_pond",           fileName: "koi_pond",           displayName: "Koi Pond",               completionMessage: "Everything worth seeing moves slowly.",                                        month: 4,  day: 11),
        Artwork(id: "maypoleVillage",     fileName: "maypoleVillage",     displayName: "Maypole Village",        completionMessage: "The ribbon doesn't know the dance. The dance knows the ribbon.",               month: 4,  day: 16),
        Artwork(id: "mossyWaterfall",     fileName: "mossyWaterfall",     displayName: "Mossy Waterfall",        completionMessage: "The moss doesn't compete with the water. It just stays.",                      month: 4,  day: 21),
        Artwork(id: "hotAirBalloonFestival",fileName:"hotAirBalloonFestival",displayName:"Hot Air Balloon Festival",completionMessage: "Everyone looks up at the same time and forgets what they were carrying.",     month: 4,  day: 26),

        // ── May — Late spring, renewal ──────────────────────────────

        Artwork(id: "forestPuddleLeaves", fileName: "forestPuddleLeaves", displayName: "Forest Puddle",          completionMessage: "The puddle holds the whole sky without trying.",                               month: 5,  day: 1),
        Artwork(id: "paperLanternShop",   fileName: "paperLanternShop",   displayName: "Paper Lantern Shop",     completionMessage: "Every lantern was once just paper and a wish.",                                month: 5,  day: 6),
        Artwork(id: "lantern",            fileName: "lantern",            displayName: "Paper Lanterns",         completionMessage: "A single flame can hold an entire evening.",                                   month: 5,  day: 11),
        Artwork(id: "riceTerraces",       fileName: "riceTerraces",       displayName: "Rice Terraces",          completionMessage: "Every step carved by hand becomes a mirror for the sky.",                      month: 5,  day: 16),
        Artwork(id: "heronGoldenHour",    fileName: "heronGoldenHour",    displayName: "Heron at Golden Hour",   completionMessage: "Patience looks a lot like standing still on purpose.",                         month: 5,  day: 21),
        Artwork(id: "mangroveHeron",      fileName: "mangroveHeron",      displayName: "Mangrove Heron",         completionMessage: "Roots that reach into water learn to hold on differently.",                    month: 5,  day: 26),

        // ── June — Early summer, open landscapes ────────────────────

        Artwork(id: "home",               fileName: "home",               displayName: "The Lake House",         completionMessage: "The lake doesn't know how beautiful it is.",                                   month: 6,  day: 1),
        Artwork(id: "dragonflyCattail",   fileName: "dragonflyCattail",   displayName: "Dragonfly & Cattails",   completionMessage: "The fastest wings know when to rest.",                                         month: 6,  day: 3),
        Artwork(id: "bench",              fileName: "bench",              displayName: "Park Bench",             completionMessage: "The best conversations happen where no one is in a hurry.",                    month: 6,  day: 6),
        Artwork(id: "wrenCactusSunset",   fileName: "wrenCactusSunset",   displayName: "Cactus Wren at Sunset",  completionMessage: "The highest perch belongs to whoever arrives first.",                          month: 6,  day: 11),
        Artwork(id: "baloon",             fileName: "baloon",             displayName: "Hot Air Balloon",        completionMessage: "The ground looks different when you stop holding on to it.",                   month: 6,  day: 16),
        Artwork(id: "balloonFestival",    fileName: "balloonFestival",    displayName: "Balloon Festival",       completionMessage: "Joy rises best when you stop holding on to it.",                               month: 6,  day: 21),
        Artwork(id: "airBalloon",         fileName: "airBalloon",         displayName: "Air Balloon",            completionMessage: "From up here, every worry is the size of a house.",                            month: 6,  day: 26),

        // ── July — Peak summer, land and coast ──────────────────────

        Artwork(id: "wheatFieldGoldenHour", fileName: "wheatFieldGoldenHour", displayName: "Wheat Field",        completionMessage: "The field bows to the wind and calls it dancing.",                             month: 7,  day: 1),
        Artwork(id: "lotusPondWater",     fileName: "lotusPondWater",     displayName: "Lotus Pond",             completionMessage: "The mud below never asks for credit.",                                         month: 7,  day: 3),
        Artwork(id: "canyon",             fileName: "canyon",             displayName: "The Canyon",             completionMessage: "The river doesn't hurry, and the canyon is its proof.",                         month: 7,  day: 6),
        Artwork(id: "desert",            fileName: "desert",             displayName: "Desert Dusk",            completionMessage: "The heat leaves first. Then the light. Then the color stays.",                  month: 7,  day: 11),
        Artwork(id: "lighthouse",         fileName: "lighthouse",         displayName: "The Lighthouse",         completionMessage: "It never asks if anyone is watching.",                                          month: 7,  day: 16),
        Artwork(id: "seaStack",           fileName: "seaStack",           displayName: "Sea Stacks",            completionMessage: "The ocean carves slowly and never second-guesses.",                              month: 7,  day: 21),
        Artwork(id: "seaStackReflection", fileName: "seaStackReflection", displayName: "Sea Stack Reflection",   completionMessage: "The reflection isn't a copy. It's a second chance to look.",                   month: 7,  day: 26),
        Artwork(id: "windmillLavender",  fileName: "windmillLavender",  displayName: "Windmill & Lavender",    completionMessage: "The wind does the turning. The lavender does the staying.",                    month: 7,  day: 29),

        // ── August — Late summer, ocean life ────────────────────────

        Artwork(id: "starFish",           fileName: "starFish",           displayName: "Starfish",               completionMessage: "The tide gives back more than it takes.",                                      month: 8,  day: 1),
        Artwork(id: "hammockPalms",      fileName: "hammockPalms",       displayName: "Hammock in the Palms",   completionMessage: "Doing nothing is the hardest thing to do on purpose.",                         month: 8,  day: 3),
        Artwork(id: "seaAnemoneRock",     fileName: "seaAnemoneRock",     displayName: "Sea Anemone",            completionMessage: "The rock is patient. The anemone is grateful.",                                month: 8,  day: 6),
        Artwork(id: "rowboatShallows",    fileName: "rowboatShallows",    displayName: "Rowboat in Shallows",    completionMessage: "The boat rests better where the water is honest.",                              month: 8,  day: 11),
        Artwork(id: "fishingBoats",       fileName: "fishingBoats",       displayName: "Fishing Boats",          completionMessage: "The harbor is safe, but that's not what boats are for.",                        month: 8,  day: 16),
        Artwork(id: "flamingoLagoon",     fileName: "flamingoLagoon",     displayName: "Flamingo Lagoon",        completionMessage: "Stillness can be the most vivid color in the room.",                           month: 8,  day: 21),
        Artwork(id: "seaTurtleReef",      fileName: "seaTurtleReef",      displayName: "Sea Turtle Reef",        completionMessage: "The reef grows slowly. The turtle knows this.",                                month: 8,  day: 26),

        // ── September — Transition, migration ───────────────────────

        Artwork(id: "turtles",            fileName: "turtles",            displayName: "Sea Turtles",            completionMessage: "They carry their home and never call it heavy.",                                month: 9,  day: 1),
        Artwork(id: "jellyfishDeepSea",   fileName: "jellyfishDeepSea",   displayName: "Jellyfish",              completionMessage: "The deep doesn't need light to be beautiful.",                                 month: 9,  day: 6),
        Artwork(id: "orcaBreaching",      fileName: "orcaBreaching",      displayName: "Orca Breaching",         completionMessage: "The surface is just another place to visit.",                                  month: 9,  day: 11),
        Artwork(id: "whaleTailOcean",     fileName: "whaleTailOcean",     displayName: "Whale Tail",             completionMessage: "The ocean remembers every dive.",                                              month: 9,  day: 16),
        Artwork(id: "ospreyDive",         fileName: "ospreyDive",         displayName: "Osprey Dive",            completionMessage: "Focus looks exactly like freedom from a distance.",                            month: 9,  day: 21),
        Artwork(id: "shorebirdsFlats",    fileName: "shorebirdsFlats",    displayName: "Shorebirds",             completionMessage: "The flock thinks together without ever speaking.",                              month: 9,  day: 26),

        // ── October — Peak autumn ───────────────────────────────────

        Artwork(id: "stormPetrelSea",     fileName: "stormPetrelSea",     displayName: "Storm Petrel",           completionMessage: "The smallest wings handle the biggest waves.",                                 month: 10, day: 1),
        Artwork(id: "saltFlatSolitude",   fileName: "saltFlatSolitude",   displayName: "Salt Flat Solitude",     completionMessage: "Emptiness has its own kind of company.",                                       month: 10, day: 5),
        Artwork(id: "highway",            fileName: "highway",            displayName: "The Highway",            completionMessage: "Every road was someone's first step away from standing still.",                 month: 10, day: 9),
        Artwork(id: "mountain",           fileName: "mountain",           displayName: "The Mountain",           completionMessage: "It was already there before anyone thought to climb it.",                       month: 10, day: 13),
        Artwork(id: "pumpkinPatch",       fileName: "pumpkinPatch",       displayName: "Pumpkin Patch",          completionMessage: "The patch grows what the season asks for.",                                     month: 10, day: 16),
        Artwork(id: "autumnDeer",         fileName: "autumnDeer",         displayName: "Autumn Deer",            completionMessage: "The forest changes first. The deer already knows.",                             month: 10, day: 18),
        Artwork(id: "owlSunsetBranch",    fileName: "owlSunsetBranch",    displayName: "Owl at Sunset",          completionMessage: "The owl sees what the sun leaves behind.",                                     month: 10, day: 23),
        Artwork(id: "pitcherPlantsBog",   fileName: "pitcherPlantsBog",   displayName: "Pitcher Plants",         completionMessage: "The bog keeps its own quiet counsel.",                                         month: 10, day: 28),

        // ── November — Deep autumn, earth and warmth ────────────────

        Artwork(id: "termiteMound",       fileName: "termiteMound",       displayName: "Termite Mound",          completionMessage: "Small efforts, piled high, become architecture.",                              month: 11, day: 1),
        Artwork(id: "mushroomForestFloor",fileName: "mushroomForestFloor",displayName: "Mushroom Forest Floor",  completionMessage: "The forest floor keeps its own quiet inventory.",                              month: 11, day: 3),
        Artwork(id: "openPitMine",        fileName: "openPitMine",        displayName: "Open Pit Mine",          completionMessage: "Depth is just a different kind of perspective.",                                month: 11, day: 6),
        Artwork(id: "elephantSavanna",    fileName: "elephantSavanna",    displayName: "Elephant on the Savanna",completionMessage: "The biggest footprints leave the softest ground.",                               month: 11, day: 11),
        Artwork(id: "papayaTree",         fileName: "papayaTree",         displayName: "Papaya Tree",            completionMessage: "Sweetness takes as long as it takes.",                                         month: 11, day: 16),
        Artwork(id: "toucanTropical",     fileName: "toucanTropical",     displayName: "Tropical Toucan",        completionMessage: "Color doesn't need an excuse to be bold.",                                     month: 11, day: 21),
        Artwork(id: "sealOnRock",         fileName: "sealOnRock",         displayName: "Seal on a Rock",         completionMessage: "Resting is not the same as waiting.",                                          month: 11, day: 26),

        // ── December — Winter returns, festivals of light ───────────

        Artwork(id: "ropeBridgeJungle",   fileName: "ropeBridgeJungle",   displayName: "Rope Bridge",            completionMessage: "Trust is just a series of small steps.",                                       month: 12, day: 1),
        Artwork(id: "moon",               fileName: "moon",               displayName: "Moonlit Night",          completionMessage: "Tonight, this moon belongs to everyone who colored it.",                        month: 12, day: 5),
        Artwork(id: "steamingCraterPool", fileName: "steamingCraterPool", displayName: "Crater Pool",            completionMessage: "The earth breathes out and the water listens.",                                month: 12, day: 9),
        Artwork(id: "volcanoCraterLake",  fileName: "volcanoCraterLake",  displayName: "Volcano Crater Lake",    completionMessage: "What once was fire is now the stillest water.",                                 month: 12, day: 13),
        Artwork(id: "papelPicadoMarket",  fileName: "papelPicadoMarket",  displayName: "Papel Picado Market",    completionMessage: "Every color in the market has a story it is too busy to tell.",                 month: 12, day: 15),
        Artwork(id: "lantern2",           fileName: "lantern2",           displayName: "Lanterns II",            completionMessage: "Light finds its way without asking for directions.",                            month: 12, day: 18),
        Artwork(id: "temple",             fileName: "temple",             displayName: "The Temple",             completionMessage: "The bell doesn't ring for anyone in particular.",                               month: 12, day: 23),
        Artwork(id: "japanese",           fileName: "japanese",           displayName: "Wisteria Garden",        completionMessage: "The garden remembers every footstep it has softened.",                          month: 12, day: 28),
    ]

    // MARK: - Date-Anchored Scheduling

    /// Deterministic daily artwork: same image for everyone on a given UTC date.
    /// Each artwork anchors to a (month, day) and stays active until the next
    /// artwork's date arrives.
    static func today() -> (artwork: Artwork, index: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let now = Date()
        let month = cal.component(.month, from: now)
        let day   = cal.component(.day,   from: now)
        return forMonthDay(month: month, day: day)
    }

    /// Find the active artwork for a given (month, day).
    /// Walks the chronologically-sorted catalog and returns the last entry
    /// whose anchor date is ≤ today's date. Wraps to the final December
    /// entry if today falls before the first artwork's anchor (Jan 1).
    static func forMonthDay(month: Int, day: Int) -> (artwork: Artwork, index: Int) {
        let todayOrd = dayOfYear(month: month, day: day)
        var bestIndex = catalog.count - 1   // default: wrap to last (Dec)
        for (i, art) in catalog.enumerated() {
            if dayOfYear(month: art.month, day: art.day) <= todayOrd {
                bestIndex = i
            }
        }
        return (catalog[bestIndex], bestIndex)
    }

    /// Preserves the Supabase completion tracking flow.
    /// Extracts (month, day) from a "yyyy-MM-dd" string and delegates
    /// to `forMonthDay`.
    static func forDateString(_ dateStr: String) -> (artwork: Artwork, index: Int) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        guard let date = f.date(from: dateStr) else {
            return (catalog[0], 0)
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let month = cal.component(.month, from: date)
        let day   = cal.component(.day,   from: date)
        return forMonthDay(month: month, day: day)
    }

    // MARK: - Helpers

    /// Approximate day-of-year ordinal (1–366). Non-leap-year offsets are
    /// fine since we only compare relative ordering within a single year.
    private static func dayOfYear(month: Int, day: Int) -> Int {
        let offsets = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        guard month >= 1, month <= 12 else { return 1 }
        return offsets[month - 1] + day
    }
}

/// The two states a daily artwork moves through.
/// The source image is never shown until the user completes the painting.
enum ArtworkPhase: Equatable {
    case painting    // Grid visible, cells fillable, palette shown
    case complete    // Grid dissolves, original image revealed with completion message
}
