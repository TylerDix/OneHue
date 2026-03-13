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

    /// 77 artworks ordered chronologically (Jan → Dec).
    /// Each artwork anchors to a specific (month, day) and remains the
    /// daily artwork until the next entry's date arrives.
    /// Placement reflects seasonal imagery, cultural resonance, and the
    /// rhythm of the natural world — without endorsing specific holidays.
    static let catalog: [Artwork] = [

        // ── January — Deep winter, fresh start ──────────────────────

        Artwork(id: "snowFox",            fileName: "snowFox",            displayName: "Snow Fox",               completionMessage: "The white fur knows that stillness is the warmest shelter.",                    month: 1,  day: 1),
        Artwork(id: "arcticFox",          fileName: "arcticFox",          displayName: "Arctic Fox",             completionMessage: "Some things survive by blending in. Others, by simply enduring.",              month: 1,  day: 6),
        Artwork(id: "penguins",           fileName: "penguins",           displayName: "Penguins",               completionMessage: "They huddle not because they're cold, but because they choose each other.",    month: 1,  day: 11),
        Artwork(id: "cozyCabin",          fileName: "cozyCabin",          displayName: "Cozy Cabin",             completionMessage: "The warmest rooms are the ones that expect nothing.",                          month: 1,  day: 17),
        Artwork(id: "owl",                fileName: "owl",                displayName: "Owl",                    completionMessage: "Wisdom is just patience that learned to sit in the dark.",                     month: 1,  day: 22),
        Artwork(id: "walrus",             fileName: "walrus",             displayName: "Walrus",                 completionMessage: "Weight is its own kind of grace when you stop apologizing for it.",            month: 1,  day: 27),

        // ── February — Winter continues, introspection ──────────────

        Artwork(id: "barnOwl",            fileName: "barnOwl",            displayName: "Barn Owl",               completionMessage: "The quietest wings carry the sharpest eyes.",                                  month: 2,  day: 1),
        Artwork(id: "owlFamily",          fileName: "owlFamily",          displayName: "Owl Family",             completionMessage: "Family is a branch that holds more than it was meant to.",                     month: 2,  day: 6),
        Artwork(id: "coveredBridge",      fileName: "coveredBridge",      displayName: "Covered Bridge",         completionMessage: "Some crossings are worth protecting from the weather.",                        month: 2,  day: 11),
        Artwork(id: "sleepyFox",          fileName: "sleepyFox",          displayName: "Sleepy Fox",             completionMessage: "Rest is the bravest thing a wild thing can do.",                               month: 2,  day: 16),
        Artwork(id: "stoneWatermill",     fileName: "stoneWatermill",     displayName: "Stone Watermill",        completionMessage: "The wheel turns because the water never stops giving.",                        month: 2,  day: 21),
        Artwork(id: "blueMountain",       fileName: "blueMountain",       displayName: "Blue Mountain",          completionMessage: "Distance is just the mountain's way of staying mysterious.",                   month: 2,  day: 26),

        // ── March — Thaw, awakening ─────────────────────────────────

        Artwork(id: "cranePink",          fileName: "cranePink",          displayName: "Pink Crane",             completionMessage: "Balance is easier when you stop looking down.",                                month: 3,  day: 1),
        Artwork(id: "beaver",             fileName: "beaver",             displayName: "Beaver",                 completionMessage: "The dam doesn't need to be perfect. It just needs to hold.",                   month: 3,  day: 5),
        Artwork(id: "deerDrinking",       fileName: "deerDrinking",       displayName: "Deer at the Stream",     completionMessage: "The clearest water reflects whoever is brave enough to lean in.",              month: 3,  day: 10),
        Artwork(id: "cherryBlossom",      fileName: "cherryBlossom",      displayName: "Cherry Blossoms",        completionMessage: "Beauty that stays forever would forget how to be beautiful.",                  month: 3,  day: 14),
        Artwork(id: "wisteriaFlowers",    fileName: "wisteriaFlowers",    displayName: "Wisteria",               completionMessage: "The heaviest blooms hang from the thinnest branches.",                         month: 3,  day: 18),
        Artwork(id: "porcupine",          fileName: "porcupine",          displayName: "Porcupine",              completionMessage: "The softest hearts build the sharpest defenses.",                              month: 3,  day: 23),
        Artwork(id: "zenGarden",          fileName: "zenGarden",          displayName: "Zen Garden",             completionMessage: "The rake marks disappear. That's the whole lesson.",                           month: 3,  day: 28),

        // ── April — Full spring, blossoms ───────────────────────────

        Artwork(id: "butteryflyGarden",   fileName: "butteryflyGarden",   displayName: "Butterfly Garden",       completionMessage: "The garden doesn't chase the butterflies. It just blooms.",                    month: 4,  day: 1),
        Artwork(id: "hummingbird",        fileName: "hummingbird",        displayName: "Hummingbird",            completionMessage: "Hovering takes more strength than flying ever could.",                         month: 4,  day: 5),
        Artwork(id: "monarchButterflies", fileName: "monarchButterflies", displayName: "Monarch Butterflies",    completionMessage: "The journey remembers itself, even when the traveler doesn't.",                month: 4,  day: 9),
        Artwork(id: "dragonfliesMeadow",  fileName: "dragonfliesMeadow",  displayName: "Dragonflies over Meadow",completionMessage: "They stitch the air above the water with invisible thread.",                   month: 4,  day: 14),
        Artwork(id: "koiPond",            fileName: "koiPond",            displayName: "Koi Pond",               completionMessage: "The fish don't know they're being watched. That's what makes them beautiful.",  month: 4,  day: 18),
        Artwork(id: "lavendarFields",     fileName: "lavendarFields",     displayName: "Lavender Fields",        completionMessage: "The wind carries the scent further than the eye can see.",                     month: 4,  day: 23),
        Artwork(id: "windmill",           fileName: "windmill",           displayName: "Windmill",               completionMessage: "It turns because it was built to face the wind, not hide from it.",            month: 4,  day: 28),

        // ── May — Late spring, renewal ──────────────────────────────

        Artwork(id: "swanGliding",        fileName: "swanGliding",        displayName: "Swan Gliding",           completionMessage: "Beneath the surface, the feet never stop moving.",                             month: 5,  day: 1),
        Artwork(id: "dragonFly",          fileName: "dragonFly",          displayName: "Dragonfly",              completionMessage: "Four wings and it still chooses to hover.",                                    month: 5,  day: 6),
        Artwork(id: "elephantFamily",     fileName: "elephantFamily",     displayName: "Elephant Family",        completionMessage: "The youngest walks in the middle. That's how you know it's love.",             month: 5,  day: 12),
        Artwork(id: "redBridge",          fileName: "redBridge",          displayName: "Red Bridge",             completionMessage: "The brightest color is the one that doesn't apologize.",                       month: 5,  day: 17),
        Artwork(id: "englishCottage",     fileName: "englishCottage",     displayName: "English Cottage",        completionMessage: "The ivy climbs because the wall invited it years ago.",                        month: 5,  day: 23),
        Artwork(id: "glassGreenhouse",    fileName: "glassGreenhouse",    displayName: "Glass Greenhouse",       completionMessage: "Everything grows when you give it shelter and light.",                         month: 5,  day: 28),

        // ── June — Early summer, open landscapes ────────────────────

        Artwork(id: "hotAir",             fileName: "hotAir",             displayName: "Hot Air Balloon",        completionMessage: "The sky has room for everyone who's willing to let go.",                       month: 6,  day: 1),
        Artwork(id: "goldenSailboat",     fileName: "goldenSailboat",     displayName: "Golden Sailboat",        completionMessage: "The sail doesn't choose the wind. It just agrees to go.",                     month: 6,  day: 5),
        Artwork(id: "castle",             fileName: "castle",             displayName: "Castle",                 completionMessage: "The strongest walls were built by someone who once felt afraid.",              month: 6,  day: 9),
        Artwork(id: "treehouse",          fileName: "treehouse",          displayName: "Treehouse",              completionMessage: "Some homes are only reachable by climbing.",                                  month: 6,  day: 13),
        Artwork(id: "venice",             fileName: "venice",             displayName: "Venice",                 completionMessage: "The city floats because it decided sinking wasn't an option.",                 month: 6,  day: 18),
        Artwork(id: "fishVillage",        fileName: "fishVillage",        displayName: "Fishing Village",        completionMessage: "The nets dry in the sun while the sea plans tomorrow.",                       month: 6,  day: 23),
        Artwork(id: "townChurch",         fileName: "townChurch",         displayName: "Town Church",            completionMessage: "The steeple points up so you don't have to.",                                 month: 6,  day: 28),

        // ── July — Peak summer, tropical ────────────────────────────

        Artwork(id: "tallLighthouse",     fileName: "tallLighthouse",     displayName: "Lighthouse",             completionMessage: "It doesn't rescue anyone. It just refuses to go dark.",                       month: 7,  day: 1),
        Artwork(id: "lighthouseDusk",     fileName: "lighthouseDusk",     displayName: "Lighthouse at Dusk",     completionMessage: "The light means more when the sky starts letting go.",                         month: 7,  day: 6),
        Artwork(id: "tropicalWaterfall",  fileName: "tropicalWaterfall",  displayName: "Tropical Waterfall",     completionMessage: "The water falls without deciding where it will land.",                         month: 7,  day: 12),
        Artwork(id: "pinkFlamingo",       fileName: "pinkFlamingo",       displayName: "Flamingo",               completionMessage: "Standing on one leg is easy when you've forgotten the other exists.",          month: 7,  day: 17),
        Artwork(id: "tropicalFish",       fileName: "tropicalFish",       displayName: "Tropical Fish",          completionMessage: "The reef paints everything that swims through it.",                            month: 7,  day: 23),
        Artwork(id: "seahorse",           fileName: "seahorse",           displayName: "Seahorse",               completionMessage: "Slowness is its own kind of current.",                                        month: 7,  day: 28),

        // ── August — Late summer, ocean life ────────────────────────

        Artwork(id: "blueJelly",          fileName: "blueJelly",          displayName: "Blue Jellyfish",         completionMessage: "No bones, no brain, no plan — and still it glows.",                           month: 8,  day: 1),
        Artwork(id: "mantaRay",           fileName: "mantaRay",           displayName: "Manta Ray",              completionMessage: "The widest wings belong to the quietest flyer.",                               month: 8,  day: 5),
        Artwork(id: "seaOtter",           fileName: "seaOtter",           displayName: "Sea Otter",              completionMessage: "Floating is easy when you hold onto what matters.",                            month: 8,  day: 9),
        Artwork(id: "dolphinLeaping",     fileName: "dolphinLeaping",     displayName: "Dolphin Leaping",        completionMessage: "Joy doesn't need a reason. It just needs a surface to break.",                month: 8,  day: 14),
        Artwork(id: "pelicanColorful",    fileName: "pelicanColorful",    displayName: "Pelican",                completionMessage: "The biggest catch fits in the smallest moment of patience.",                   month: 8,  day: 18),
        Artwork(id: "pingFlamingo",       fileName: "pingFlamingo",       displayName: "Flamingo Pair",          completionMessage: "Pink is just confidence wearing feathers.",                                    month: 8,  day: 23),
        Artwork(id: "jelly",              fileName: "jelly",              displayName: "Jellyfish",              completionMessage: "Drifting is a decision the current made for both of you.",                     month: 8,  day: 28),

        // ── September — Transition, birds ───────────────────────────

        Artwork(id: "baldEagle",          fileName: "baldEagle",          displayName: "Bald Eagle",             completionMessage: "The highest branches belong to whoever refuses to look away.",                 month: 9,  day: 1),
        Artwork(id: "eagleSouring",       fileName: "eagleSouring",       displayName: "Soaring Eagle",          completionMessage: "The wind does the lifting. The wings do the trusting.",                        month: 9,  day: 6),
        Artwork(id: "parrot",             fileName: "parrot",             displayName: "Parrot",                 completionMessage: "The brightest voice in the forest has nothing to prove.",                      month: 9,  day: 11),
        Artwork(id: "twoParrots",         fileName: "twoParrots",         displayName: "Two Parrots",            completionMessage: "Conversation is just color with a heartbeat.",                                month: 9,  day: 16),
        Artwork(id: "toucanPerched",      fileName: "toucanPerched",      displayName: "Toucan",                 completionMessage: "The beak carries more color than the branch can hold.",                       month: 9,  day: 22),
        Artwork(id: "roadrunner",         fileName: "roadrunner",         displayName: "Roadrunner",             completionMessage: "Speed only matters when you know where the dust settles.",                     month: 9,  day: 27),

        // ── October — Peak autumn ───────────────────────────────────

        Artwork(id: "moose",              fileName: "moose",              displayName: "Moose",                  completionMessage: "The forest makes room for anything that walks slowly enough.",                 month: 10, day: 1),
        Artwork(id: "mountainGoat",       fileName: "mountainGoat",       displayName: "Mountain Goat",          completionMessage: "The ledge was never as narrow as it looked from below.",                       month: 10, day: 5),
        Artwork(id: "gazelleSavanna",     fileName: "gazelleSavanna",     displayName: "Gazelle",                completionMessage: "Grace is just fear that learned how to leap.",                                 month: 10, day: 9),
        Artwork(id: "bison",              fileName: "bison",              displayName: "Bison",                  completionMessage: "The prairie parts for what refuses to go around.",                             month: 10, day: 14),
        Artwork(id: "tigerStalking",      fileName: "tigerStalking",      displayName: "Tiger",                  completionMessage: "Stripes are just the jungle remembering where the light fell.",               month: 10, day: 18),
        Artwork(id: "purpleMoose",        fileName: "purpleMoose",        displayName: "Purple Moose",           completionMessage: "Some colors exist only because someone imagined them.",                        month: 10, day: 23),
        Artwork(id: "birdFish",           fileName: "birdFish",           displayName: "Bird and Fish",          completionMessage: "They meet where the water ends and the air begins.",                          month: 10, day: 28),

        // ── November — Deep autumn, earth and warmth ────────────────

        Artwork(id: "gorilla",            fileName: "gorilla",            displayName: "Gorilla",                completionMessage: "Strength sits quietly until the forest needs it.",                             month: 11, day: 1),
        Artwork(id: "giantPanda",         fileName: "giantPanda",         displayName: "Giant Panda",            completionMessage: "The gentlest giants eat the simplest meals.",                                  month: 11, day: 6),
        Artwork(id: "koala",              fileName: "koala",              displayName: "Koala",                  completionMessage: "Napping is an art when you've found the right branch.",                        month: 11, day: 12),
        Artwork(id: "alpacas",            fileName: "alpacas",            displayName: "Alpacas",                completionMessage: "The softest wool comes from the most patient animals.",                        month: 11, day: 17),
        Artwork(id: "racoonLake",         fileName: "racoonLake",         displayName: "Raccoon at the Lake",    completionMessage: "Curiosity washes everything twice, just to be sure.",                          month: 11, day: 23),
        Artwork(id: "chameleo",           fileName: "chameleo",           displayName: "Chameleon",              completionMessage: "Changing color isn't hiding. It's listening to the room.",                     month: 11, day: 28),

        // ── December — Winter returns, wonder ───────────────────────

        Artwork(id: "penguinFam",         fileName: "penguinFam",         displayName: "Penguin Family",         completionMessage: "The coldest place on earth still has the warmest huddles.",                    month: 12, day: 1),
        Artwork(id: "pandaBamboo",        fileName: "pandaBamboo",        displayName: "Panda in Bamboo",        completionMessage: "The bamboo grows back. The panda always knew it would.",                       month: 12, day: 6),
        Artwork(id: "peacockBlue",        fileName: "peacockBlue",        displayName: "Peacock",                completionMessage: "The display isn't for you. It's for the one who sees it anyway.",              month: 12, day: 11),
        Artwork(id: "firefliesGlowing",   fileName: "firefliesGlowing",   displayName: "Fireflies",              completionMessage: "A thousand small lights outshine anything that tries to burn alone.",          month: 12, day: 16),
        Artwork(id: "carouselHourse",     fileName: "carouselHourse",     displayName: "Carousel Horse",         completionMessage: "It goes in circles and still makes children believe in journeys.",             month: 12, day: 22),
        Artwork(id: "weirdBird",          fileName: "weirdBird",          displayName: "Strange Bird",           completionMessage: "The ones who don't quite fit are the ones you remember.",                     month: 12, day: 27),
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
