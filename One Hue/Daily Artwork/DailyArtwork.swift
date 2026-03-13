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

    /// 146 artworks ordered chronologically (Jan → Dec).
    /// Each artwork anchors to a specific (month, day) and remains the
    /// daily artwork until the next entry's date arrives.
    /// Placement reflects seasonal imagery, cultural resonance, and the
    /// rhythm of the natural world — without endorsing specific holidays.
    static let catalog: [Artwork] = [

        // ── January — Deep winter, fresh start ──────────────────────

        Artwork(id: "snowFox",            fileName: "snowFox",            displayName: "Snow Fox",               completionMessage: "The white fur knows that stillness is the warmest shelter.",                    month: 1,  day: 1),
        Artwork(id: "arcticFox",          fileName: "arcticFox",          displayName: "Arctic Fox",             completionMessage: "Some things survive by blending in. Others, by simply enduring.",              month: 1,  day: 4),
        Artwork(id: "penguins",           fileName: "penguins",           displayName: "Penguins",               completionMessage: "They huddle not because they're cold, but because they choose each other.",    month: 1,  day: 7),
        Artwork(id: "snowCabin",          fileName: "snowCabin",          displayName: "Snow Cabin",             completionMessage: "The deepest snow falls quietest around the places that glow.",                month: 1,  day: 10),
        Artwork(id: "cozyCabin",          fileName: "cozyCabin",          displayName: "Cozy Cabin",             completionMessage: "The warmest rooms are the ones that expect nothing.",                          month: 1,  day: 13),
        Artwork(id: "frozenLake",         fileName: "frozenLake",         displayName: "Frozen Lake",            completionMessage: "Stillness is just the lake remembering what it was before the wind.",          month: 1,  day: 16),
        Artwork(id: "arcticFoxSnow",      fileName: "arcticFoxSnow",      displayName: "Arctic Fox in Snow",     completionMessage: "The fox sleeps deepest where the snow erases all paths.",                       month: 1,  day: 18),
        Artwork(id: "owl",                fileName: "owl",                displayName: "Owl",                    completionMessage: "Wisdom is just patience that learned to sit in the dark.",                     month: 1,  day: 20),
        Artwork(id: "iceFishingLake",     fileName: "iceFishingLake",     displayName: "Ice Fishing Lake",       completionMessage: "Patience has a hut and a hole in the ice.",                                    month: 1,  day: 22),
        Artwork(id: "fjord",              fileName: "fjord",              displayName: "Norwegian Fjord",        completionMessage: "The cliffs don't lean in. They've simply forgotten how to move apart.",        month: 1,  day: 24),
        Artwork(id: "wolfHowling",        fileName: "wolfHowling",        displayName: "Wolf Howling",           completionMessage: "The howl doesn't ask for an answer. It just fills the silence.",               month: 1,  day: 26),
        Artwork(id: "walrus",             fileName: "walrus",             displayName: "Walrus",                 completionMessage: "Weight is its own kind of grace when you stop apologizing for it.",            month: 1,  day: 28),

        // ── February — Winter continues, introspection ──────────────

        Artwork(id: "barnOwl",            fileName: "barnOwl",            displayName: "Barn Owl",               completionMessage: "The quietest wings carry the sharpest eyes.",                                  month: 2,  day: 1),
        Artwork(id: "owlFamily",          fileName: "owlFamily",          displayName: "Owl Family",             completionMessage: "Family is a branch that holds more than it was meant to.",                     month: 2,  day: 4),
        Artwork(id: "glacialLake",        fileName: "glacialLake",        displayName: "Glacial Lake",           completionMessage: "The mountain only shows its face to water that holds perfectly still.",        month: 2,  day: 7),
        Artwork(id: "coveredBridge",      fileName: "coveredBridge",      displayName: "Covered Bridge",         completionMessage: "Some crossings are worth protecting from the weather.",                        month: 2,  day: 10),
        Artwork(id: "sleepyFox",          fileName: "sleepyFox",          displayName: "Sleepy Fox",             completionMessage: "Rest is the bravest thing a wild thing can do.",                               month: 2,  day: 13),
        Artwork(id: "hotSpring",          fileName: "hotSpring",          displayName: "Hot Spring",             completionMessage: "The earth offers warmth to anyone willing to sit with the cold.",              month: 2,  day: 16),
        Artwork(id: "stoneWatermill",     fileName: "stoneWatermill",     displayName: "Stone Watermill",        completionMessage: "The wheel turns because the water never stops giving.",                        month: 2,  day: 19),
        Artwork(id: "polarBearCub",      fileName: "polarBearCub",       displayName: "Polar Bear and Cub",    completionMessage: "The smallest footprints follow the biggest ones through the snow.",            month: 2,  day: 21),
        Artwork(id: "stormLighthouse",    fileName: "stormLighthouse",    displayName: "Storm Lighthouse",       completionMessage: "Standing alone in the storm isn't courage. It's just knowing you're needed.", month: 2,  day: 23),
        Artwork(id: "frozenWaterfallBlue",fileName: "frozenWaterfallBlue",displayName: "Frozen Waterfall",       completionMessage: "Even the waterfall rests when winter asks it to.",                              month: 2,  day: 25),
        Artwork(id: "blueMountain",       fileName: "blueMountain",       displayName: "Blue Mountain",          completionMessage: "Distance is just the mountain's way of staying mysterious.",                   month: 2,  day: 27),

        // ── March — Thaw, awakening ─────────────────────────────────

        Artwork(id: "cranePink",          fileName: "cranePink",          displayName: "Pink Crane",             completionMessage: "Balance is easier when you stop looking down.",                                month: 3,  day: 1),
        Artwork(id: "kingfisher",         fileName: "kingfisher",         displayName: "Kingfisher",             completionMessage: "Patience looks effortless from the branch above.",                             month: 3,  day: 4),
        Artwork(id: "beaver",             fileName: "beaver",             displayName: "Beaver",                 completionMessage: "The dam doesn't need to be perfect. It just needs to hold.",                   month: 3,  day: 7),
        Artwork(id: "deerDrinking",       fileName: "deerDrinking",       displayName: "Deer at the Stream",     completionMessage: "The clearest water reflects whoever is brave enough to lean in.",              month: 3,  day: 10),
        Artwork(id: "rockyCoastline",     fileName: "rockyCoastline",     displayName: "Rocky Coastline",        completionMessage: "The rocks don't fight the waves. They just remember what they are.",           month: 3,  day: 13),
        Artwork(id: "templeGardenKoi",    fileName: "templeGardenKoi",    displayName: "Temple Garden",          completionMessage: "The koi circle the pond because they've learned there is no arriving.",        month: 3,  day: 14),
        Artwork(id: "cherryBlossom",      fileName: "cherryBlossom",      displayName: "Cherry Blossoms",        completionMessage: "Beauty that stays forever would forget how to be beautiful.",                  month: 3,  day: 16),
        Artwork(id: "wisteriaFlowers",    fileName: "wisteriaFlowers",    displayName: "Wisteria",               completionMessage: "The heaviest blooms hang from the thinnest branches.",                         month: 3,  day: 18),
        Artwork(id: "wisteriaArbor",      fileName: "wisteriaArbor",      displayName: "Wisteria Arbor",         completionMessage: "Some things grow best when they have something to lean on.",                   month: 3,  day: 20),
        Artwork(id: "iceCave",            fileName: "iceCave",            displayName: "Ice Cave",               completionMessage: "The light finds a way in, even through something frozen solid.",               month: 3,  day: 21),
        Artwork(id: "porcupine",          fileName: "porcupine",          displayName: "Porcupine",              completionMessage: "The softest hearts build the sharpest defenses.",                              month: 3,  day: 23),
        Artwork(id: "redwoodCathedral",   fileName: "redwoodCathedral",   displayName: "Redwood Cathedral",      completionMessage: "The oldest trees hold the light without grasping.",                            month: 3,  day: 26),
        Artwork(id: "zenGarden",          fileName: "zenGarden",          displayName: "Zen Garden",             completionMessage: "The rake marks disappear. That's the whole lesson.",                           month: 3,  day: 29),

        // ── April — Full spring, blossoms ───────────────────────────

        Artwork(id: "butteryflyGarden",   fileName: "butteryflyGarden",   displayName: "Butterfly Garden",       completionMessage: "The garden doesn't chase the butterflies. It just blooms.",                    month: 4,  day: 1),
        Artwork(id: "hummingbird",        fileName: "hummingbird",        displayName: "Hummingbird",            completionMessage: "Hovering takes more strength than flying ever could.",                         month: 4,  day: 4),
        Artwork(id: "hillsideVillage",    fileName: "hillsideVillage",    displayName: "Hillside Village",       completionMessage: "The houses climb because the view is worth the stairs.",                       month: 4,  day: 7),
        Artwork(id: "monarchButterflies", fileName: "monarchButterflies", displayName: "Monarch Butterflies",    completionMessage: "The journey remembers itself, even when the traveler doesn't.",                month: 4,  day: 10),
        Artwork(id: "venetianCanal",      fileName: "venetianCanal",      displayName: "Venetian Canal",         completionMessage: "Even still water knows where it's going.",                                     month: 4,  day: 13),
        Artwork(id: "dragonfliesMeadow",  fileName: "dragonfliesMeadow",  displayName: "Dragonflies over Meadow",completionMessage: "They stitch the air above the water with invisible thread.",                   month: 4,  day: 16),
        Artwork(id: "koiPond",            fileName: "koiPond",            displayName: "Koi Pond",               completionMessage: "The fish don't know they're being watched. That's what makes them beautiful.",  month: 4,  day: 19),
        Artwork(id: "harborLowTide",      fileName: "harborLowTide",      displayName: "Harbor at Low Tide",     completionMessage: "The tide always returns for what it left behind.",                              month: 4,  day: 22),
        Artwork(id: "bambooForestPath",   fileName: "bambooForestPath",   displayName: "Bamboo Forest",          completionMessage: "The tallest stalks grow by not looking at their neighbors.",                    month: 4,  day: 24),
        Artwork(id: "lavendarFields",     fileName: "lavendarFields",     displayName: "Lavender Fields",        completionMessage: "The wind carries the scent further than the eye can see.",                     month: 4,  day: 25),
        Artwork(id: "gardenGateRoses",   fileName: "gardenGateRoses",    displayName: "Garden Gate",            completionMessage: "The gate is open because the roses already decided who belongs.",              month: 4,  day: 27),
        Artwork(id: "windmill",           fileName: "windmill",           displayName: "Windmill",               completionMessage: "It turns because it was built to face the wind, not hide from it.",            month: 4,  day: 29),

        // ── May — Late spring, renewal ──────────────────────────────

        Artwork(id: "swanGliding",        fileName: "swanGliding",        displayName: "Swan Gliding",           completionMessage: "Beneath the surface, the feet never stop moving.",                             month: 5,  day: 1),
        Artwork(id: "coastalWindmill",    fileName: "coastalWindmill",    displayName: "Coastal Windmill",       completionMessage: "The wind works hardest where it meets the edge of the world.",                 month: 5,  day: 4),
        Artwork(id: "dragonFly",          fileName: "dragonFly",          displayName: "Dragonfly",              completionMessage: "Four wings and it still chooses to hover.",                                    month: 5,  day: 7),
        Artwork(id: "seaCave",            fileName: "seaCave",            displayName: "Sea Cave",               completionMessage: "Standing at the edge is how you learn what's behind you.",                     month: 5,  day: 10),
        Artwork(id: "elephantFamily",     fileName: "elephantFamily",     displayName: "Elephant Family",        completionMessage: "The youngest walks in the middle. That's how you know it's love.",             month: 5,  day: 13),
        Artwork(id: "wildflowerMeadow",  fileName: "wildflowerMeadow",   displayName: "Wildflower Meadow",     completionMessage: "The meadow doesn't plan its colors. It just opens everything at once.",        month: 5,  day: 15),
        Artwork(id: "provenceLavender",   fileName: "provenceLavender",   displayName: "Provence Lavender",      completionMessage: "The fields don't rush to bloom. They just agree on a color.",                  month: 5,  day: 17),
        Artwork(id: "redBridge",          fileName: "redBridge",          displayName: "Red Bridge",             completionMessage: "The brightest color is the one that doesn't apologize.",                       month: 5,  day: 20),
        Artwork(id: "canopyWalkway",      fileName: "canopyWalkway",      displayName: "Canopy Walkway",         completionMessage: "The highest paths belong to those who trust what holds them.",                  month: 5,  day: 23),
        Artwork(id: "englishCottage",     fileName: "englishCottage",     displayName: "English Cottage",        completionMessage: "The ivy climbs because the wall invited it years ago.",                        month: 5,  day: 26),
        Artwork(id: "glassGreenhouse",    fileName: "glassGreenhouse",    displayName: "Glass Greenhouse",       completionMessage: "Everything grows when you give it shelter and light.",                         month: 5,  day: 29),

        // ── June — Early summer, open landscapes ────────────────────

        Artwork(id: "hotAir",             fileName: "hotAir",             displayName: "Hot Air Balloon",        completionMessage: "The sky has room for everyone who's willing to let go.",                       month: 6,  day: 1),
        Artwork(id: "goldenSailboat",     fileName: "goldenSailboat",     displayName: "Golden Sailboat",        completionMessage: "The sail doesn't choose the wind. It just agrees to go.",                     month: 6,  day: 4),
        Artwork(id: "greekIsland",        fileName: "greekIsland",        displayName: "Greek Island",           completionMessage: "White walls and blue doors — simplicity is its own architecture.",             month: 6,  day: 7),
        Artwork(id: "castle",             fileName: "castle",             displayName: "Castle",                 completionMessage: "The strongest walls were built by someone who once felt afraid.",              month: 6,  day: 10),
        Artwork(id: "treehouse",          fileName: "treehouse",          displayName: "Treehouse",              completionMessage: "Some homes are only reachable by climbing.",                                  month: 6,  day: 13),
        Artwork(id: "tuscanRoad",         fileName: "tuscanRoad",         displayName: "Tuscan Road",            completionMessage: "The road lined with cypresses asks nothing but that you keep going.",          month: 6,  day: 16),
        Artwork(id: "venice",             fileName: "venice",             displayName: "Venice",                 completionMessage: "The city floats because it decided sinking wasn't an option.",                 month: 6,  day: 19),
        Artwork(id: "ropeBridge",         fileName: "ropeBridge",         displayName: "Rope Bridge",            completionMessage: "The bravest step is the one where both sides disappear.",                      month: 6,  day: 22),
        Artwork(id: "fishingPierSunset",  fileName: "fishingPierSunset",  displayName: "Fishing Pier at Sunset", completionMessage: "The pier stretches out because the horizon never comes closer.",               month: 6,  day: 24),
        Artwork(id: "fishVillage",        fileName: "fishVillage",        displayName: "Fishing Village",        completionMessage: "The nets dry in the sun while the sea plans tomorrow.",                       month: 6,  day: 27),
        Artwork(id: "townChurch",         fileName: "townChurch",         displayName: "Town Church",            completionMessage: "The steeple points up so you don't have to.",                                 month: 6,  day: 29),

        // ── July — Peak summer, tropical ────────────────────────────

        Artwork(id: "tallLighthouse",     fileName: "tallLighthouse",     displayName: "Lighthouse",             completionMessage: "It doesn't rescue anyone. It just refuses to go dark.",                       month: 7,  day: 1),
        Artwork(id: "lighthouseDusk",     fileName: "lighthouseDusk",     displayName: "Lighthouse at Dusk",     completionMessage: "The light means more when the sky starts letting go.",                         month: 7,  day: 4),
        Artwork(id: "jungleWaterfall",    fileName: "jungleWaterfall",    displayName: "Jungle Waterfall",       completionMessage: "The water doesn't choose the cliff. It just refuses to stop.",                month: 7,  day: 7),
        Artwork(id: "tropicalWaterfall",  fileName: "tropicalWaterfall",  displayName: "Tropical Waterfall",     completionMessage: "The water falls without deciding where it will land.",                         month: 7,  day: 10),
        Artwork(id: "coralReef",          fileName: "coralReef",          displayName: "Coral Reef",             completionMessage: "A thousand small lives build the architecture no one planned.",                month: 7,  day: 13),
        Artwork(id: "tidePools",          fileName: "tidePools",          displayName: "Tide Pools",             completionMessage: "The ocean leaves its brightest secrets in the smallest hollows.",              month: 7,  day: 15),
        Artwork(id: "pinkFlamingo",       fileName: "pinkFlamingo",       displayName: "Flamingo",               completionMessage: "Standing on one leg is easy when you've forgotten the other exists.",          month: 7,  day: 17),
        Artwork(id: "junglePool",         fileName: "junglePool",         displayName: "Jungle Pool",            completionMessage: "The jungle hides its calmest places behind the loudest green.",                month: 7,  day: 20),
        Artwork(id: "desertOasis",        fileName: "desertOasis",        displayName: "Desert Oasis",           completionMessage: "The palms drink deep because they know the sand offers nothing twice.",        month: 7,  day: 22),
        Artwork(id: "sandDunes",          fileName: "sandDunes",          displayName: "Sand Dunes",             completionMessage: "The desert remembers every wind that ever touched it.",                        month: 7,  day: 24),
        Artwork(id: "tropicalFish",       fileName: "tropicalFish",       displayName: "Tropical Fish",          completionMessage: "The reef paints everything that swims through it.",                            month: 7,  day: 26),
        Artwork(id: "seahorse",           fileName: "seahorse",           displayName: "Seahorse",               completionMessage: "Slowness is its own kind of current.",                                        month: 7,  day: 29),

        // ── August — Late summer, ocean life ────────────────────────

        Artwork(id: "blueJelly",          fileName: "blueJelly",          displayName: "Blue Jellyfish",         completionMessage: "No bones, no brain, no plan — and still it glows.",                           month: 8,  day: 1),
        Artwork(id: "mantaRay",           fileName: "mantaRay",           displayName: "Manta Ray",              completionMessage: "The widest wings belong to the quietest flyer.",                               month: 8,  day: 4),
        Artwork(id: "humpbackWhale",      fileName: "humpbackWhale",      displayName: "Humpback Whale",         completionMessage: "Breaking the surface is just the ocean exhaling through something enormous.",  month: 8,  day: 7),
        Artwork(id: "seaOtter",           fileName: "seaOtter",           displayName: "Sea Otter",              completionMessage: "Floating is easy when you hold onto what matters.",                            month: 8,  day: 10),
        Artwork(id: "dolphinLeaping",     fileName: "dolphinLeaping",     displayName: "Dolphin Leaping",        completionMessage: "Joy doesn't need a reason. It just needs a surface to break.",                month: 8,  day: 13),
        Artwork(id: "mountainRowboat",    fileName: "mountainRowboat",    displayName: "Mountain Rowboat",       completionMessage: "A boat tied to a dock is still dreaming of the far shore.",                    month: 8,  day: 16),
        Artwork(id: "pelicanColorful",    fileName: "pelicanColorful",    displayName: "Pelican",                completionMessage: "The biggest catch fits in the smallest moment of patience.",                   month: 8,  day: 19),
        Artwork(id: "alpineMeadow",       fileName: "alpineMeadow",       displayName: "Alpine Meadow",          completionMessage: "The wildflowers bloom without knowing anyone is watching.",                     month: 8,  day: 21),
        Artwork(id: "desertMesa",         fileName: "desertMesa",         displayName: "Desert Mesa",            completionMessage: "The mesa stands because erosion forgot to take everything.",                   month: 8,  day: 23),
        Artwork(id: "grizzlySalmon",     fileName: "grizzlySalmon",      displayName: "Grizzly Bear Fishing",  completionMessage: "The river gives to whoever stands still long enough.",                          month: 8,  day: 25),
        Artwork(id: "pingFlamingo",       fileName: "pingFlamingo",       displayName: "Flamingo Pair",          completionMessage: "Pink is just confidence wearing feathers.",                                    month: 8,  day: 26),
        Artwork(id: "jelly",              fileName: "jelly",              displayName: "Jellyfish",              completionMessage: "Drifting is a decision the current made for both of you.",                     month: 8,  day: 29),

        // ── September — Transition, birds ───────────────────────────

        Artwork(id: "baldEagle",          fileName: "baldEagle",          displayName: "Bald Eagle",             completionMessage: "The highest branches belong to whoever refuses to look away.",                 month: 9,  day: 1),
        Artwork(id: "coastalTidePools",   fileName: "coastalTidePools",   displayName: "Coastal Tide Pools",     completionMessage: "The ocean leaves small gifts in every hollow it finds.",                        month: 9,  day: 3),
        Artwork(id: "coastalCliffs",      fileName: "coastalCliffs",      displayName: "Coastal Cliffs",         completionMessage: "The lighthouse asks nothing of the ships. It just stays lit.",                 month: 9,  day: 5),
        Artwork(id: "eagleSouring",       fileName: "eagleSouring",       displayName: "Soaring Eagle",          completionMessage: "The wind does the lifting. The wings do the trusting.",                        month: 9,  day: 7),
        Artwork(id: "pandaBamboo",       fileName: "pandaBamboo",        displayName: "Panda in Bamboo",       completionMessage: "The bamboo grows around the panda, or maybe it's the other way.",              month: 9,  day: 9),
        Artwork(id: "observatory",        fileName: "observatory",        displayName: "Observatory",            completionMessage: "The dome opens for anyone willing to stay up past the stars.",                 month: 9,  day: 10),
        Artwork(id: "parrot",             fileName: "parrot",             displayName: "Parrot",                 completionMessage: "The brightest voice in the forest has nothing to prove.",                      month: 9,  day: 13),
        Artwork(id: "twoParrots",         fileName: "twoParrots",         displayName: "Two Parrots",            completionMessage: "Conversation is just color with a heartbeat.",                                month: 9,  day: 16),
        Artwork(id: "cathedralInterior",  fileName: "cathedralInterior",  displayName: "Cathedral Interior",     completionMessage: "Light through old glass falls on everyone the same.",                          month: 9,  day: 19),
        Artwork(id: "romanAqueduct",      fileName: "romanAqueduct",      displayName: "Roman Aqueduct",         completionMessage: "The arches carry water the way memory carries what once mattered.",            month: 9,  day: 21),
        Artwork(id: "toucanPerched",      fileName: "toucanPerched",      displayName: "Toucan",                 completionMessage: "The beak carries more color than the branch can hold.",                       month: 9,  day: 23),
        Artwork(id: "potteryWorkshop",    fileName: "potteryWorkshop",    displayName: "Pottery Workshop",       completionMessage: "The wheel turns and the clay remembers what your hands forgot.",               month: 9,  day: 26),
        Artwork(id: "roadrunner",         fileName: "roadrunner",         displayName: "Roadrunner",             completionMessage: "Speed only matters when you know where the dust settles.",                     month: 9,  day: 29),

        // ── October — Peak autumn ───────────────────────────────────

        Artwork(id: "moose",              fileName: "moose",              displayName: "Moose",                  completionMessage: "The forest makes room for anything that walks slowly enough.",                 month: 10, day: 1),
        Artwork(id: "autumnOrchard",      fileName: "autumnOrchard",      displayName: "Autumn Orchard",         completionMessage: "The tree gives its fruit to whatever hand shows up in autumn.",                month: 10, day: 4),
        Artwork(id: "mountainGoat",       fileName: "mountainGoat",       displayName: "Mountain Goat",          completionMessage: "The ledge was never as narrow as it looked from below.",                       month: 10, day: 7),
        Artwork(id: "gazelleSavanna",     fileName: "gazelleSavanna",     displayName: "Gazelle",                completionMessage: "Grace is just fear that learned how to leap.",                                 month: 10, day: 9),
        Artwork(id: "autumnBarn",        fileName: "autumnBarn",          displayName: "Autumn Barn",           completionMessage: "The barn holds the harvest like a promise it made to the field.",               month: 10, day: 10),
        Artwork(id: "redCoveredBridge",   fileName: "redCoveredBridge",   displayName: "Red Covered Bridge",     completionMessage: "The bridge wears red so you never lose your way home.",                        month: 10, day: 12),
        Artwork(id: "bison",              fileName: "bison",              displayName: "Bison",                  completionMessage: "The prairie parts for what refuses to go around.",                             month: 10, day: 15),
        Artwork(id: "tigerStalking",      fileName: "tigerStalking",      displayName: "Tiger",                  completionMessage: "Stripes are just the jungle remembering where the light fell.",               month: 10, day: 18),
        Artwork(id: "scottishHighlands",  fileName: "scottishHighlands",  displayName: "Scottish Highlands",     completionMessage: "The ruins stay because the stone has nowhere else to be.",                     month: 10, day: 21),
        Artwork(id: "purpleMoose",        fileName: "purpleMoose",        displayName: "Purple Moose",           completionMessage: "Some colors exist only because someone imagined them.",                        month: 10, day: 24),
        Artwork(id: "autumnBench",        fileName: "autumnBench",        displayName: "Autumn Bench",           completionMessage: "The bench waits for no one, yet holds a place for everyone.",                  month: 10, day: 27),
        Artwork(id: "autumnForestPath",  fileName: "autumnForestPath",   displayName: "Autumn Forest Path",    completionMessage: "The path doesn't end. It just changes what it's covered with.",                month: 10, day: 29),
        Artwork(id: "birdFish",           fileName: "birdFish",           displayName: "Bird and Fish",          completionMessage: "They meet where the water ends and the air begins.",                          month: 10, day: 30),

        // ── November — Deep autumn, earth and warmth ────────────────

        Artwork(id: "gorilla",            fileName: "gorilla",            displayName: "Gorilla",                completionMessage: "Strength sits quietly until the forest needs it.",                             month: 11, day: 1),
        Artwork(id: "giantPanda",         fileName: "giantPanda",         displayName: "Giant Panda",            completionMessage: "The gentlest giants eat the simplest meals.",                                  month: 11, day: 4),
        Artwork(id: "rainyParis",         fileName: "rainyParis",         displayName: "Rainy Paris",            completionMessage: "The city shines brightest when the sky gives it something to reflect.",        month: 11, day: 7),
        Artwork(id: "koala",              fileName: "koala",              displayName: "Koala",                  completionMessage: "Napping is an art when you've found the right branch.",                        month: 11, day: 10),
        Artwork(id: "cobblestoneAlley",   fileName: "cobblestoneAlley",   displayName: "Cobblestone Alley",      completionMessage: "Every stone was placed by someone who never saw the cafe lights.",             month: 11, day: 13),
        Artwork(id: "terracedVineyard",   fileName: "terracedVineyard",   displayName: "Terraced Vineyard",      completionMessage: "The hill was too steep until someone decided to build steps for grapes.",      month: 11, day: 16),
        Artwork(id: "alpacas",            fileName: "alpacas",            displayName: "Alpacas",                completionMessage: "The softest wool comes from the most patient animals.",                        month: 11, day: 19),
        Artwork(id: "stoneArchBridge",    fileName: "stoneArchBridge",    displayName: "Stone Arch Bridge",      completionMessage: "The arch holds because every stone leans on its neighbor.",                    month: 11, day: 22),
        Artwork(id: "ravensBirch",       fileName: "ravensBirch",        displayName: "Ravens on Birch",       completionMessage: "Two dark shapes on white bark — winter's own calligraphy.",                    month: 11, day: 24),
        Artwork(id: "racoonLake",         fileName: "racoonLake",         displayName: "Raccoon at the Lake",    completionMessage: "Curiosity washes everything twice, just to be sure.",                          month: 11, day: 26),
        Artwork(id: "chameleo",           fileName: "chameleo",           displayName: "Chameleon",              completionMessage: "Changing color isn't hiding. It's listening to the room.",                     month: 11, day: 29),

        // ── December — Winter returns, wonder ───────────────────────

        Artwork(id: "penguinFam",         fileName: "penguinFam",         displayName: "Penguin Family",         completionMessage: "The coldest place on earth still has the warmest huddles.",                    month: 12, day: 1),
        Artwork(id: "harborRowboats",     fileName: "harborRowboats",     displayName: "Harbor Rowboats",        completionMessage: "The boats rest together because the harbor holds them all the same.",          month: 12, day: 3),
        Artwork(id: "snowyVillage",       fileName: "snowyVillage",       displayName: "Snowy Village",          completionMessage: "The village glows brightest when the snow asks it to.",                        month: 12, day: 5),
        Artwork(id: "peacockBlue",        fileName: "peacockBlue",        displayName: "Peacock",                completionMessage: "The display isn't for you. It's for the one who sees it anyway.",              month: 12, day: 8),
        Artwork(id: "wolfMoonlight",     fileName: "wolfMoonlight",      displayName: "Wolf in Moonlight",     completionMessage: "The moon doesn't answer. That's why the wolf keeps asking.",                   month: 12, day: 9),
        Artwork(id: "libraryRoom",        fileName: "libraryRoom",        displayName: "Library Room",           completionMessage: "Every unread book is a conversation waiting to begin.",                        month: 12, day: 11),
        Artwork(id: "frozenWaterfall",   fileName: "frozenWaterfall",    displayName: "Frozen Cascade",        completionMessage: "The water remembers how to fall, even when it's standing still.",              month: 12, day: 13),
        Artwork(id: "firefliesGlowing",   fileName: "firefliesGlowing",   displayName: "Fireflies",              completionMessage: "A thousand small lights outshine anything that tries to burn alone.",          month: 12, day: 15),
        Artwork(id: "auroraBorealis",    fileName: "auroraBorealis",     displayName: "Aurora Borealis",       completionMessage: "The sky dances when it thinks no one is watching.",                             month: 12, day: 17),
        Artwork(id: "carouselHourse",     fileName: "carouselHourse",     displayName: "Carousel Horse",         completionMessage: "It goes in circles and still makes children believe in journeys.",             month: 12, day: 19),
        Artwork(id: "wineCellar",         fileName: "wineCellar",         displayName: "Wine Cellar",            completionMessage: "Patience tastes better in the dark.",                                         month: 12, day: 22),
        Artwork(id: "winterSleigh",      fileName: "winterSleigh",       displayName: "Winter Sleigh",         completionMessage: "The lantern swings because the path ahead is worth lighting.",                 month: 12, day: 24),
        Artwork(id: "weirdBird",          fileName: "weirdBird",          displayName: "Strange Bird",           completionMessage: "The ones who don't quite fit are the ones you remember.",                     month: 12, day: 26),
        Artwork(id: "winterMarket",      fileName: "winterMarket",       displayName: "Winter Market",         completionMessage: "The warmest nights are the ones spent outdoors with strangers.",               month: 12, day: 28),
        Artwork(id: "stoneArchCove",      fileName: "stoneArchCove",      displayName: "Stone Arch Cove",        completionMessage: "Stand small before something ancient. That's where perspective begins.",      month: 12, day: 30),
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
