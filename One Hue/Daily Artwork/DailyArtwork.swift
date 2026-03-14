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

    /// 275 artworks ordered chronologically (Jan → Dec).
    /// Each artwork anchors to a specific (month, day) and remains the
    /// daily artwork until the next entry's date arrives.
    /// Placement reflects seasonal imagery, cultural resonance, and the
    /// rhythm of the natural world — without endorsing specific holidays.
    static let catalog: [Artwork] = [

        // ── January — Deep winter, fresh start ──────────────────────

        Artwork(id: "snowFox",            fileName: "snowFox",            displayName: "Snow Fox",               completionMessage: "The white fur knows that stillness is the warmest shelter.",                    month: 1,  day: 1),
        Artwork(id: "icicleCave",        fileName: "icicleCave",        displayName: "Icicle Cave",            completionMessage: "The cave hangs its chandeliers for whoever dares to enter.",                    month: 1,  day: 2),
        Artwork(id: "snowyOwlPerch",     fileName: "snowyOwlPerch",     displayName: "Snowy Owl Perch",        completionMessage: "The frost-covered post is a throne for whoever waits longest.",                 month: 1,  day: 3),
        Artwork(id: "staveChurch",        fileName: "staveChurch",        displayName: "Stave Church",           completionMessage: "The oldest timber still holds the shape of someone's prayer.",                  month: 1,  day: 4),
        Artwork(id: "chickadeeWinterberry",fileName:"chickadeeWinterberry",displayName: "Chickadee on Winterberry",completionMessage: "The smallest songs carry the farthest in frozen air.",                         month: 1,  day: 5),
        Artwork(id: "polarExpressTrain",  fileName: "polarExpressTrain",  displayName: "Polar Express Train",    completionMessage: "The train only stops for those who still believe in the journey.",             month: 1,  day: 6),
        Artwork(id: "penguins",           fileName: "penguins",           displayName: "Penguins",               completionMessage: "They huddle not because they're cold, but because they choose each other.",    month: 1,  day: 7),
        Artwork(id: "ermineSnow",         fileName: "ermineSnow",         displayName: "Ermine in Snow",         completionMessage: "The smallest hunter wears the whitest coat.",                                   month: 1,  day: 8),
        Artwork(id: "iceSkaters",          fileName: "iceSkaters",          displayName: "Ice Skaters",            completionMessage: "The ice holds everyone who trusts it enough to glide.",                        month: 1,  day: 9),
        Artwork(id: "snowCabin",          fileName: "snowCabin",          displayName: "Snow Cabin",             completionMessage: "The deepest snow falls quietest around the places that glow.",                month: 1,  day: 10),
        Artwork(id: "dogSledTeam",        fileName: "dogSledTeam",        displayName: "Dog Sled Team",          completionMessage: "The trail is only as strong as the trust between the lead dog and the last.",  month: 1,  day: 12),
        Artwork(id: "cozyCabin",          fileName: "cozyCabin",          displayName: "Cozy Cabin",             completionMessage: "The warmest rooms are the ones that expect nothing.",                          month: 1,  day: 13),
        Artwork(id: "arcticFox",          fileName: "arcticFox",          displayName: "Arctic Fox",             completionMessage: "Some things survive by blending in. Others, by simply enduring.",              month: 1,  day: 15),
        Artwork(id: "frozenLake",         fileName: "frozenLake",         displayName: "Frozen Lake",            completionMessage: "Stillness is just the lake remembering what it was before the wind.",          month: 1,  day: 16),
        Artwork(id: "iceFishingShanty",  fileName: "iceFishingShanty",  displayName: "Ice Fishing Shanty",     completionMessage: "Color stands out bravest on a frozen lake.",                                    month: 1,  day: 17),
        Artwork(id: "barnOwlHunting",    fileName: "barnOwlHunting",    displayName: "Barn Owl Hunting",       completionMessage: "The silent wings read the snow like a letter from the field.",                  month: 1,  day: 18),
        Artwork(id: "mooseAtTwilight",   fileName: "mooseAtTwilight",   displayName: "Moose at Twilight",      completionMessage: "The biggest silhouette moves softest through the purple hour.",                 month: 1,  day: 19),
        Artwork(id: "fishUnderIce",       fileName: "fishUnderIce",       displayName: "Fish Under Ice",         completionMessage: "Beneath the stillness, life keeps its own quiet rhythm.",                       month: 1,  day: 20),
        Artwork(id: "snowLeopard",         fileName: "snowLeopard",         displayName: "Snow Leopard",           completionMessage: "The ghost of the mountain moves without leaving a trace.",                      month: 1,  day: 21),
        Artwork(id: "owl",                fileName: "owl",                displayName: "Owl",                    completionMessage: "Wisdom is just patience that learned to sit in the dark.",                     month: 1,  day: 22),
        Artwork(id: "iceFishingLake",     fileName: "iceFishingLake",     displayName: "Ice Fishing Lake",       completionMessage: "Patience has a hut and a hole in the ice.",                                    month: 1,  day: 23),
        Artwork(id: "fjord",              fileName: "fjord",              displayName: "Norwegian Fjord",        completionMessage: "The cliffs don't lean in. They've simply forgotten how to move apart.",        month: 1,  day: 24),
        Artwork(id: "arcticFoxSnow",      fileName: "arcticFoxSnow",      displayName: "Arctic Fox in Snow",     completionMessage: "The fox sleeps deepest where the snow erases all paths.",                       month: 1,  day: 25),
        Artwork(id: "wolfHowling",        fileName: "wolfHowling",        displayName: "Wolf Howling",           completionMessage: "The howl doesn't ask for an answer. It just fills the silence.",               month: 1,  day: 26),
        Artwork(id: "walrus",             fileName: "walrus",             displayName: "Walrus",                 completionMessage: "Weight is its own kind of grace when you stop apologizing for it.",            month: 1,  day: 27),
        Artwork(id: "chineseNewYearDragon",fileName:"chineseNewYearDragon",displayName:"Chinese New Year Dragon",completionMessage: "The dragon dances because the new year needs reminding that joy is loud.",     month: 1,  day: 28),
        Artwork(id: "lighthouseCliffs",  fileName: "lighthouseCliffs",   displayName: "Lighthouse Cliffs",      completionMessage: "The light holds steady because the storm never asked permission.",             month: 1,  day: 29),
        Artwork(id: "polarBearMother",   fileName: "polarBearMother",   displayName: "Polar Bear Mother",      completionMessage: "The smallest paws follow the largest across the endless white.",               month: 1,  day: 30),

        // ── February — Winter continues, introspection ──────────────

        Artwork(id: "barnOwl",            fileName: "barnOwl",            displayName: "Barn Owl",               completionMessage: "The quietest wings carry the sharpest eyes.",                                  month: 2,  day: 1),
        Artwork(id: "hibernatingHedgehog",fileName:"hibernatingHedgehog", displayName: "Hibernating Hedgehog",  completionMessage: "The deepest sleep belongs to those who trust the thaw will come.",              month: 2,  day: 2),
        Artwork(id: "barnAtDawn",         fileName: "barnAtDawn",         displayName: "Barn at Dawn",           completionMessage: "The rooster crows and the barn answers with the smell of hay.",                month: 2,  day: 3),
        Artwork(id: "owlFamily",          fileName: "owlFamily",          displayName: "Owl Family",             completionMessage: "Family is a branch that holds more than it was meant to.",                     month: 2,  day: 4),
        Artwork(id: "deerBirchGrove",    fileName: "deerBirchGrove",    displayName: "Deer in Birch Grove",    completionMessage: "White bark and white tail — the forest keeps its own camouflage.",              month: 2,  day: 5),
        Artwork(id: "winterGreenhouse",   fileName: "winterGreenhouse",   displayName: "Winter Greenhouse",      completionMessage: "The glass holds summer hostage while winter presses its face against the pane.",month: 2,  day: 6),
        Artwork(id: "glacialLake",        fileName: "glacialLake",        displayName: "Glacial Lake",           completionMessage: "The mountain only shows its face to water that holds perfectly still.",        month: 2,  day: 7),
        Artwork(id: "mountainHotSpring", fileName: "mountainHotSpring", displayName: "Mountain Hot Spring",    completionMessage: "The earth offers its warmth where the snow presses hardest.",                   month: 2,  day: 8),
        Artwork(id: "crossCountrySkier", fileName: "crossCountrySkier",  displayName: "Cross-Country Skier",    completionMessage: "The tracks behind you are proof the forest let you through.",                   month: 2,  day: 9),
        Artwork(id: "coveredBridge",      fileName: "coveredBridge",      displayName: "Covered Bridge",         completionMessage: "Some crossings are worth protecting from the weather.",                        month: 2,  day: 10),
        Artwork(id: "lunarLanterns",     fileName: "lunarLanterns",     displayName: "Lunar Lanterns",         completionMessage: "Red and gold carry every wish the old year left behind.",                       month: 2,  day: 11),
        Artwork(id: "mardiGrasMasks",     fileName: "mardiGrasMasks",     displayName: "Mardi Gras Masks",       completionMessage: "Behind every mask is someone who chose celebration over hiding.",               month: 2,  day: 12),
        Artwork(id: "swanLakeValentine", fileName: "swanLakeValentine", displayName: "Swan Lake Valentine",    completionMessage: "Two necks bend into a shape the heart already knew.",                           month: 2,  day: 13),
        Artwork(id: "hotSpring",          fileName: "hotSpring",          displayName: "Hot Spring",             completionMessage: "The earth offers warmth to anyone willing to sit with the cold.",              month: 2,  day: 16),
        Artwork(id: "robinSnowdrops",     fileName: "robinSnowdrops",     displayName: "Robin and Snowdrops",    completionMessage: "The first flowers and the first song arrive on the same morning.",              month: 2,  day: 17),
        Artwork(id: "stoneWatermill",     fileName: "stoneWatermill",     displayName: "Stone Watermill",        completionMessage: "The wheel turns because the water never stops giving.",                        month: 2,  day: 19),
        Artwork(id: "mapleSyrupTapping", fileName: "mapleSyrupTapping", displayName: "Maple Syrup Tapping",    completionMessage: "The sweetest sap runs when winter finally loosens its grip.",                   month: 2,  day: 20),
        Artwork(id: "polarBearCub",      fileName: "polarBearCub",       displayName: "Polar Bear and Cub",    completionMessage: "The smallest footprints follow the biggest ones through the snow.",            month: 2,  day: 21),
        Artwork(id: "penguinColony",     fileName: "penguinColony",     displayName: "Penguin Colony",         completionMessage: "The huddle holds because every body shares the same cold.",                    month: 2,  day: 22),
        Artwork(id: "gondolaSkiLift",     fileName: "gondolaSkiLift",     displayName: "Gondola Ski Lift",       completionMessage: "The summit waits for those who trust the cable and the climb.",                 month: 2,  day: 24),
        Artwork(id: "frozenWaterfallBlue",fileName: "frozenWaterfallBlue",displayName: "Frozen Waterfall",       completionMessage: "Even the waterfall rests when winter asks it to.",                              month: 2,  day: 25),
        Artwork(id: "bisonYellowstone",  fileName: "bisonYellowstone",  displayName: "Bison in Yellowstone",   completionMessage: "The herd walks through steam because the earth still breathes here.",           month: 2,  day: 26),
        Artwork(id: "blueMountain",       fileName: "blueMountain",       displayName: "Blue Mountain",          completionMessage: "Distance is just the mountain's way of staying mysterious.",                   month: 2,  day: 27),

        // ── March — Thaw, awakening ─────────────────────────────────

        Artwork(id: "cranePink",          fileName: "cranePink",          displayName: "Pink Crane",             completionMessage: "Balance is easier when you stop looking down.",                                month: 3,  day: 1),
        Artwork(id: "kingfisher",         fileName: "kingfisher",         displayName: "Kingfisher",             completionMessage: "Patience looks effortless from the branch above.",                             month: 3,  day: 2),
        Artwork(id: "hareSpringThaw",     fileName: "hareSpringThaw",     displayName: "Hare in Spring Thaw",    completionMessage: "The first brave thing to move after winter is always the smallest.",            month: 3,  day: 5),
        Artwork(id: "vikingLongship",     fileName: "vikingLongship",     displayName: "Viking Longship",        completionMessage: "The dragon prow parts the fog so the crew doesn't have to fear it.",           month: 3,  day: 6),
        Artwork(id: "beaver",             fileName: "beaver",             displayName: "Beaver",                 completionMessage: "The dam doesn't need to be perfect. It just needs to hold.",                   month: 3,  day: 7),
        Artwork(id: "geeseMigration",     fileName: "geeseMigration",     displayName: "Geese Migration",        completionMessage: "The V holds because every bird trusts the one in front.",                       month: 3,  day: 8),
        Artwork(id: "crocusBreakthrough",fileName: "crocusBreakthrough",displayName: "Crocus Breakthrough",    completionMessage: "The first color of spring pushes through because it forgot to be afraid.",     month: 3,  day: 9),
        Artwork(id: "deerDrinking",       fileName: "deerDrinking",       displayName: "Deer at the Stream",     completionMessage: "The clearest water reflects whoever is brave enough to lean in.",              month: 3,  day: 10),
        Artwork(id: "cozyCabinSmoke",    fileName: "cozyCabinSmoke",    displayName: "Cabin Smoke",            completionMessage: "The chimney speaks in gray curls to a sky that always listens.",                month: 3,  day: 11),
        Artwork(id: "holiFestival",       fileName: "holiFestival",       displayName: "Holi Festival",          completionMessage: "The brightest colors land on whoever stands closest to the joy.",              month: 3,  day: 12),
        Artwork(id: "rockyCoastline",     fileName: "rockyCoastline",     displayName: "Rocky Coastline",        completionMessage: "The rocks don't fight the waves. They just remember what they are.",           month: 3,  day: 13),
        Artwork(id: "kiteFestival",       fileName: "kiteFestival",       displayName: "Kite Festival",          completionMessage: "The string only matters to the one holding it. The kite already knows the wind.", month: 3, day: 15),
        Artwork(id: "cherryBlossom",      fileName: "cherryBlossom",      displayName: "Cherry Blossoms",        completionMessage: "Beauty that stays forever would forget how to be beautiful.",                  month: 3,  day: 16),
        Artwork(id: "wisteriaFlowers",    fileName: "wisteriaFlowers",    displayName: "Wisteria",               completionMessage: "The heaviest blooms hang from the thinnest branches.",                         month: 3,  day: 18),
        Artwork(id: "wolfSnow",           fileName: "wolfSnow",           displayName: "Wolf in Snow",           completionMessage: "The forest falls silent not from fear, but from respect.",                       month: 3,  day: 19),
        Artwork(id: "porcupine",          fileName: "porcupine",          displayName: "Porcupine",              completionMessage: "The softest hearts build the sharpest defenses.",                              month: 3,  day: 20),
        Artwork(id: "iceCave",            fileName: "iceCave",            displayName: "Ice Cave",               completionMessage: "The light finds a way in, even through something frozen solid.",               month: 3,  day: 21),
        Artwork(id: "frozenCascade",     fileName: "frozenWaterfall",    displayName: "Frozen Cascade",        completionMessage: "The water remembers how to fall, even when it's standing still.",              month: 3,  day: 22),
        Artwork(id: "wisteriaArbor",      fileName: "wisteriaArbor",      displayName: "Wisteria Arbor",         completionMessage: "Some things grow best when they have something to lean on.",                   month: 3,  day: 23),
        Artwork(id: "penguinFam",         fileName: "penguinFam",         displayName: "Penguin Family",         completionMessage: "The coldest place on earth still has the warmest huddles.",                    month: 3,  day: 24),
        Artwork(id: "ottersThawingRiver", fileName: "ottersThawingRiver", displayName: "Otters on a Thawing River",completionMessage: "Play is how the river remembers it's allowed to move again.",                 month: 3,  day: 25),
        Artwork(id: "redwoodCathedral",   fileName: "redwoodCathedral",   displayName: "Redwood Cathedral",      completionMessage: "The oldest trees hold the light without grasping.",                            month: 3,  day: 26),
        Artwork(id: "cherryBlossomTemple",fileName:"cherryBlossomTemple",displayName:"Cherry Blossom Temple",  completionMessage: "The petals fall on the temple steps like small pink prayers.",                  month: 3,  day: 27),
        Artwork(id: "auroraBorealis",    fileName: "auroraBorealis",     displayName: "Aurora Borealis",       completionMessage: "The sky dances when it thinks no one is watching.",                             month: 3,  day: 28),
        Artwork(id: "springLambsDawn",   fileName: "springLambsDawn",   displayName: "Spring Lambs at Dawn",   completionMessage: "New legs learn the meadow one wobble at a time.",                               month: 3,  day: 30),

        Artwork(id: "snowyVillage",       fileName: "snowyVillage",       displayName: "Snowy Village",          completionMessage: "The village glows brightest when the snow asks it to.",                        month: 3,  day: 31),

        // ── April — Full spring, blossoms ───────────────────────────

        Artwork(id: "butteryflyGarden",   fileName: "butteryflyGarden",   displayName: "Butterfly Garden",       completionMessage: "The garden doesn't chase the butterflies. It just blooms.",                    month: 4,  day: 1),
        Artwork(id: "windmillTulips",    fileName: "windmillTulips",     displayName: "Windmill & Tulips",      completionMessage: "The blades turn and the tulips nod — each answering the same wind.",            month: 4,  day: 2),
        Artwork(id: "beeGarden",           fileName: "beeGarden",           displayName: "Bee Garden",             completionMessage: "Every flower is a doorway only the smallest travelers know.",                   month: 4,  day: 3),
        Artwork(id: "pitcherPlantsBog",   fileName: "pitcherPlantsBog",   displayName: "Pitcher Plants Bog",     completionMessage: "The prettiest traps wait with their mouths open and their patience endless.",    month: 4,  day: 4),
        Artwork(id: "hummingbird",        fileName: "hummingbird",        displayName: "Hummingbird",            completionMessage: "Hovering takes more strength than flying ever could.",                         month: 4,  day: 5),
        Artwork(id: "peacockBlue",        fileName: "peacockBlue",        displayName: "Peacock",                completionMessage: "The display isn't for you. It's for the one who sees it anyway.",              month: 4,  day: 6),
        Artwork(id: "hillsideVillage",    fileName: "hillsideVillage",    displayName: "Hillside Village",       completionMessage: "The houses climb because the view is worth the stairs.",                       month: 4,  day: 7),
        Artwork(id: "samuraiGarden",      fileName: "samuraiGarden",      displayName: "Samurai Garden",         completionMessage: "The warrior rests where the blossoms fall without fighting.",                   month: 4,  day: 8),
        Artwork(id: "libraryRoom",        fileName: "libraryRoom",        displayName: "Library Room",           completionMessage: "Every unread book is a conversation waiting to begin.",                        month: 4,  day: 9),
        Artwork(id: "monarchButterflies", fileName: "monarchButterflies", displayName: "Monarch Butterflies",    completionMessage: "The journey remembers itself, even when the traveler doesn't.",                month: 4,  day: 10),
        Artwork(id: "harborRowboats",     fileName: "harborRowboats",     displayName: "Harbor Rowboats",        completionMessage: "The boats rest together because the harbor holds them all the same.",          month: 4,  day: 11),
        Artwork(id: "rainforestWaterfall",fileName:"rainforestWaterfall",displayName:"Rainforest Waterfall",   completionMessage: "The jungle hides its loudest wonder behind the quietest green.",               month: 4,  day: 12),
        Artwork(id: "venetianCanal",      fileName: "venetianCanal",      displayName: "Venetian Canal",         completionMessage: "Even still water knows where it's going.",                                     month: 4,  day: 13),
        Artwork(id: "storkNest",          fileName: "storkNest",          displayName: "Stork Nest",             completionMessage: "The chimney didn't ask for a family. The stork decided for it.",               month: 4,  day: 14),
        Artwork(id: "stoneArchCove",      fileName: "stoneArchCove",      displayName: "Stone Arch Cove",        completionMessage: "Stand small before something ancient. That's where perspective begins.",      month: 4,  day: 15),
        Artwork(id: "dragonfliesMeadow",  fileName: "dragonfliesMeadow",  displayName: "Dragonflies over Meadow",completionMessage: "They stitch the air above the water with invisible thread.",                   month: 4,  day: 16),
        Artwork(id: "wisteriaBridge",    fileName: "wisteriaBridge",    displayName: "Wisteria Bridge",        completionMessage: "The bridge wears purple because the vine chose beauty over speed.",             month: 4,  day: 17),
        Artwork(id: "koiPond",            fileName: "koiPond",            displayName: "Koi Pond",               completionMessage: "The fish don't know they're being watched. That's what makes them beautiful.",  month: 4,  day: 19),
        Artwork(id: "maroonTemple",       fileName: "maroonTemple",       displayName: "Pagoda Bridge",          completionMessage: "The bridge and the pagoda share the same reflection.",                         month: 4,  day: 20),
        Artwork(id: "firefliesGlowing",   fileName: "firefliesGlowing",   displayName: "Fireflies",              completionMessage: "A thousand small lights outshine anything that tries to burn alone.",          month: 4,  day: 21),
        Artwork(id: "harborLowTide",      fileName: "harborLowTide",      displayName: "Harbor at Low Tide",     completionMessage: "The tide always returns for what it left behind.",                              month: 4,  day: 22),
        Artwork(id: "redPanda",            fileName: "redPanda",            displayName: "Red Panda",              completionMessage: "The quietest climber finds the sweetest branch.",                              month: 4,  day: 23),
        Artwork(id: "snowyGreenhouseGlow", fileName: "snowyGreenhouseGlow", displayName: "Snowy Greenhouse",       completionMessage: "Even in winter, something insists on growing.",                                 month: 12, day: 25),
        Artwork(id: "bambooForestPath",   fileName: "bambooForestPath",   displayName: "Bamboo Forest",          completionMessage: "The tallest stalks grow by not looking at their neighbors.",                    month: 4,  day: 25),
        Artwork(id: "lavendarFields",     fileName: "lavendarFields",     displayName: "Lavender Fields",        completionMessage: "The wind carries the scent further than the eye can see.",                     month: 4,  day: 26),
        Artwork(id: "gardenGateRoses",   fileName: "gardenGateRoses",    displayName: "Garden Gate",            completionMessage: "The gate is open because the roses already decided who belongs.",              month: 4,  day: 27),
        Artwork(id: "wolfMoonlight",     fileName: "wolfMoonlight",      displayName: "Wolf in Moonlight",     completionMessage: "The moon doesn't answer. That's why the wolf keeps asking.",                   month: 4,  day: 28),
        Artwork(id: "windmill",           fileName: "windmill",           displayName: "Windmill",               completionMessage: "It turns because it was built to face the wind, not hide from it.",            month: 4,  day: 29),
        Artwork(id: "wineCellar",         fileName: "wineCellar",         displayName: "Wine Cellar",            completionMessage: "Patience tastes better in the dark.",                                         month: 4,  day: 30),

        // ── May — Late spring, renewal ──────────────────────────────

        Artwork(id: "swanGliding",        fileName: "swanGliding",        displayName: "Swan Gliding",           completionMessage: "Beneath the surface, the feet never stop moving.",                             month: 5,  day: 1),
        Artwork(id: "gardenMaze",        fileName: "gardenMaze",         displayName: "Garden Maze",            completionMessage: "Every wrong turn still teaches you something about the hedges.",               month: 5,  day: 2),
        Artwork(id: "rowboatShallows",    fileName: "rowboatShallows",    displayName: "Rowboat in Shallows",    completionMessage: "The clearest water shows you everything the boat is resting on.",               month: 5,  day: 3),
        Artwork(id: "riceTerraces",       fileName: "riceTerraces",       displayName: "Rice Terraces",          completionMessage: "The mountain learned to hold water by letting people reshape it.",             month: 5,  day: 5),
        Artwork(id: "driftwoodPebbles",   fileName: "driftwoodPebbles",   displayName: "Driftwood and Pebbles",  completionMessage: "The sea polishes everything it can't keep.",                                    month: 5,  day: 6),
        Artwork(id: "dragonFly",          fileName: "dragonFly",          displayName: "Dragonfly",              completionMessage: "Four wings and it still chooses to hover.",                                    month: 5,  day: 7),
        Artwork(id: "cappadociaBalloons", fileName: "cappadociaBalloons", displayName: "Cappadocia Balloons",    completionMessage: "The earth carved the chimneys. The sky brought the colors.",                   month: 5,  day: 8),
        Artwork(id: "weirdBird",          fileName: "weirdBird",          displayName: "Strange Bird",           completionMessage: "The ones who don't quite fit are the ones you remember.",                     month: 5,  day: 9),
        Artwork(id: "winterMarket",      fileName: "winterMarket",       displayName: "Winter Market",         completionMessage: "The warmest nights are the ones spent outdoors with strangers.",               month: 5,  day: 11),
        Artwork(id: "foxCrossingStream", fileName: "foxCrossingStream", displayName: "Fox Crossing Stream",    completionMessage: "The stepping stones were always there — the fox just had to trust them.",       month: 5,  day: 12),
        Artwork(id: "elephantFamily",     fileName: "elephantFamily",     displayName: "Elephant Family",        completionMessage: "The youngest walks in the middle. That's how you know it's love.",             month: 5,  day: 13),
        Artwork(id: "robinStoneWall",    fileName: "robinStoneWall",    displayName: "Robin on Stone Wall",    completionMessage: "The wall tells its stories to whatever small bird will listen.",               month: 5,  day: 14),
        Artwork(id: "wildflowerMeadow",  fileName: "wildflowerMeadow",   displayName: "Wildflower Meadow",     completionMessage: "The meadow doesn't plan its colors. It just opens everything at once.",        month: 5,  day: 15),
        Artwork(id: "prairieDogTown",     fileName: "prairieDogTown",     displayName: "Prairie Dog Town",       completionMessage: "The lookout whistles and the whole town listens.",                             month: 5,  day: 16),
        Artwork(id: "magnoliaBlossoms",  fileName: "magnoliaBlossoms",  displayName: "Magnolia Blossoms",     completionMessage: "The blossoms open wide because they have nothing left to hide.",               month: 5,  day: 18),
        Artwork(id: "redBridge",          fileName: "redBridge",          displayName: "Red Bridge",             completionMessage: "The brightest color is the one that doesn't apologize.",                       month: 5,  day: 20),
        Artwork(id: "tadpolePond",       fileName: "tadpolePond",       displayName: "Tadpole Pond",           completionMessage: "Every swimmer starts by forgetting it was ever anything else.",                 month: 5,  day: 21),
        Artwork(id: "stainedGlassPeacock",fileName: "stainedGlassPeacock",displayName: "Stained Glass Peacock",  completionMessage: "The light breaks into color only when it passes through something beautiful.",  month: 5,  day: 22),
        Artwork(id: "canopyWalkway",      fileName: "canopyWalkway",      displayName: "Canopy Walkway",         completionMessage: "The highest paths belong to those who trust what holds them.",                  month: 5,  day: 24),
        Artwork(id: "englishCottage",     fileName: "englishCottage",     displayName: "English Cottage",        completionMessage: "The ivy climbs because the wall invited it years ago.",                        month: 5,  day: 26),
        Artwork(id: "glassGreenhouse",    fileName: "glassGreenhouse",    displayName: "Glass Greenhouse",       completionMessage: "Everything grows when you give it shelter and light.",                         month: 5,  day: 29),

        // ── June — Early summer, open landscapes ────────────────────

        Artwork(id: "hotAir",             fileName: "hotAir",             displayName: "Hot Air Balloon",        completionMessage: "The sky has room for everyone who's willing to let go.",                       month: 6,  day: 1),
        Artwork(id: "elephantSavanna",   fileName: "elephantSavanna",    displayName: "Elephant Savanna",       completionMessage: "The biggest footprints leave the softest echo on dry earth.",                   month: 6,  day: 2),
        Artwork(id: "heronMoonlitLake",   fileName: "heronMoonlitLake",   displayName: "Heron on Moonlit Lake",  completionMessage: "The heron waits because the moon makes the fish forget to hide.",               month: 6,  day: 3),
        Artwork(id: "goldenSailboat",     fileName: "goldenSailboat",     displayName: "Golden Sailboat",        completionMessage: "The sail doesn't choose the wind. It just agrees to go.",                     month: 6,  day: 4),
        Artwork(id: "dragonBoatRace",     fileName: "dragonBoatRace",     displayName: "Dragon Boat Race",       completionMessage: "The drums keep time so the paddles can keep faith.",                           month: 6,  day: 5),
        Artwork(id: "floatingMarket",     fileName: "floatingMarket",     displayName: "Floating Market",        completionMessage: "Commerce floats wherever people carry their generosity.",                      month: 6,  day: 6),
        Artwork(id: "monetBridge",        fileName: "monetBridge",        displayName: "Monet Bridge",           completionMessage: "The water lilies never asked to be painted. They just kept blooming.",         month: 6,  day: 7),
        Artwork(id: "flamingoLagoon",    fileName: "flamingoLagoon",    displayName: "Flamingo Lagoon",        completionMessage: "Standing in color is easy when you are the color.",                            month: 6,  day: 9),
        Artwork(id: "castle",             fileName: "castle",             displayName: "Castle",                 completionMessage: "The strongest walls were built by someone who once felt afraid.",              month: 6,  day: 10),
        Artwork(id: "mossyWaterfall",     fileName: "mossyWaterfall",     displayName: "Mossy Waterfall",        completionMessage: "The moss grows thickest where the water never stops singing.",                  month: 6,  day: 11),
        Artwork(id: "hummingbirdGarden", fileName: "hummingbirdGarden", displayName: "Hummingbird Garden",     completionMessage: "The smallest wings visit every bloom the garden has to offer.",                month: 6,  day: 12),
        Artwork(id: "treehouse",          fileName: "treehouse",          displayName: "Treehouse",              completionMessage: "Some homes are only reachable by climbing.",                                  month: 6,  day: 13),
        Artwork(id: "puffinCliff",        fileName: "puffinCliff",        displayName: "Puffin Cliff",           completionMessage: "The clumsiest flier still finds the bravest cliff to call home.",              month: 6,  day: 14),
        Artwork(id: "wrenCactusSunset",   fileName: "wrenCactusSunset",   displayName: "Cactus Wren at Sunset",  completionMessage: "The highest perch in the desert belongs to whoever sings first.",               month: 6,  day: 15),
        Artwork(id: "tuscanRoad",         fileName: "tuscanRoad",         displayName: "Tuscan Road",            completionMessage: "The road lined with cypresses asks nothing but that you keep going.",          month: 6,  day: 16),
        Artwork(id: "pelicanBay",         fileName: "pelicanBay",         displayName: "Pelican Bay",            completionMessage: "The pier holds still while the pelicans decide when to dive.",                 month: 6,  day: 18),
        Artwork(id: "venice",             fileName: "venice",             displayName: "Venice",                 completionMessage: "The city floats because it decided sinking wasn't an option.",                 month: 6,  day: 19),
        Artwork(id: "vintageBiplane",     fileName: "vintageBiplane",     displayName: "Vintage Biplane",        completionMessage: "The oldest wings still remember what it means to leave the ground.",           month: 6,  day: 21),
        Artwork(id: "ropeBridge",         fileName: "ropeBridge",         displayName: "Rope Bridge",            completionMessage: "The bravest step is the one where both sides disappear.",                      month: 6,  day: 22),
        Artwork(id: "riverKayaking",     fileName: "riverKayaking",      displayName: "River Kayaking",         completionMessage: "The canyon carved itself with the same water you're paddling through.",         month: 6,  day: 23),
        Artwork(id: "fishingPierSunset",  fileName: "fishingPierSunset",  displayName: "Fishing Pier at Sunset", completionMessage: "The pier stretches out because the horizon never comes closer.",               month: 6,  day: 24),
        Artwork(id: "trainStation",      fileName: "trainStation",       displayName: "Train Station",          completionMessage: "The clock only matters to the ones who haven't boarded yet.",                   month: 6,  day: 25),
        Artwork(id: "fishVillage",        fileName: "fishVillage",        displayName: "Fishing Village",        completionMessage: "The nets dry in the sun while the sea plans tomorrow.",                       month: 6,  day: 27),
        Artwork(id: "townChurch",         fileName: "townChurch",         displayName: "Town Church",            completionMessage: "The steeple points up so you don't have to.",                                 month: 6,  day: 29),

        // ── July — Peak summer, tropical ────────────────────────────

        Artwork(id: "tallLighthouse",     fileName: "tallLighthouse",     displayName: "Lighthouse",             completionMessage: "It doesn't rescue anyone. It just refuses to go dark.",                       month: 7,  day: 1),
        Artwork(id: "ferrisWheelCarnival",fileName:"ferrisWheelCarnival",displayName: "Carnival Night",         completionMessage: "The wheel lifts everyone the same height, one seat at a time.",                month: 7,  day: 2),
        Artwork(id: "volcanoIsland",     fileName: "volcanoIsland",      displayName: "Volcano Island",         completionMessage: "The island builds itself one eruption at a time.",                              month: 7,  day: 3),
        Artwork(id: "lighthouseDusk",     fileName: "lighthouseDusk",     displayName: "Lighthouse at Dusk",     completionMessage: "The light means more when the sky starts letting go.",                         month: 7,  day: 4),
        Artwork(id: "orcaBreaching",      fileName: "orcaBreaching",      displayName: "Orca Breaching",         completionMessage: "The ocean lets go of its biggest secret in one breath.",                        month: 7,  day: 5),
        Artwork(id: "seaTurtleReef",      fileName: "seaTurtleReef",      displayName: "Sea Turtle Reef",        completionMessage: "The shell carries a home and the current carries the rest.",                    month: 7,  day: 6),
        Artwork(id: "jungleWaterfall",    fileName: "jungleWaterfall",    displayName: "Jungle Waterfall",       completionMessage: "The water doesn't choose the cliff. It just refuses to stop.",                month: 7,  day: 7),
        Artwork(id: "mermaidLagoon",      fileName: "mermaidLagoon",      displayName: "Mermaid Lagoon",         completionMessage: "The lagoon keeps its secrets just below the surface.",                         month: 7,  day: 8),
        Artwork(id: "shorebirdsFlats",    fileName: "shorebirdsFlats",    displayName: "Shorebirds on the Flats",completionMessage: "The tide pulls back and the birds arrive like they were waiting.",               month: 7,  day: 9),
        Artwork(id: "tropicalWaterfall",  fileName: "tropicalWaterfall",  displayName: "Tropical Waterfall",     completionMessage: "The water falls without deciding where it will land.",                         month: 7,  day: 10),
        Artwork(id: "heronGoldenHour",   fileName: "heronGoldenHour",   displayName: "Heron at Golden Hour",   completionMessage: "The heron turns golden when the hour does.",                                   month: 7,  day: 11),
        Artwork(id: "ospryDivingWaves",  fileName: "ospryDivingWaves",  displayName: "Osprey Diving Waves",    completionMessage: "The plunge succeeds because hesitation was never invited.",                    month: 7,  day: 12),
        Artwork(id: "coralReef",          fileName: "coralReef",          displayName: "Coral Reef",             completionMessage: "A thousand small lives build the architecture no one planned.",                month: 7,  day: 13),
        Artwork(id: "seaAnemoneRock",     fileName: "seaAnemoneRock",     displayName: "Sea Anemone on Rock",    completionMessage: "The softest creature holds the hardest surface and calls it home.",              month: 7,  day: 14),
        Artwork(id: "tidePools",          fileName: "tidePools",          displayName: "Tide Pools",             completionMessage: "The ocean leaves its brightest secrets in the smallest hollows.",              month: 7,  day: 15),
        Artwork(id: "submarinePorthole",  fileName: "submarinePorthole",  displayName: "Submarine Porthole",     completionMessage: "The glass holds back the ocean so you can see what it's hiding.",              month: 7,  day: 16),
        Artwork(id: "pinkFlamingo",       fileName: "pinkFlamingo",       displayName: "Flamingo",               completionMessage: "Standing on one leg is easy when you've forgotten the other exists.",          month: 7,  day: 17),
        Artwork(id: "hammockBeach",       fileName: "hammockBeach",       displayName: "Hammock Beach",          completionMessage: "The best view comes with no plans and two palm trees.",                        month: 7,  day: 19),
        Artwork(id: "junglePool",         fileName: "junglePool",         displayName: "Jungle Pool",            completionMessage: "The jungle hides its calmest places behind the loudest green.",                month: 7,  day: 20),
        Artwork(id: "octopusGarden",     fileName: "octopusGarden",     displayName: "Octopus Garden",         completionMessage: "Eight arms and still it holds the ocean gently.",                              month: 7,  day: 21),
        Artwork(id: "desertOasis",        fileName: "desertOasis",        displayName: "Desert Oasis",           completionMessage: "The palms drink deep because they know the sand offers nothing twice.",        month: 7,  day: 22),
        Artwork(id: "sandDunes",          fileName: "sandDunes",          displayName: "Sand Dunes",             completionMessage: "The desert remembers every wind that ever touched it.",                        month: 7,  day: 24),
        Artwork(id: "strawberry",         fileName: "strawberry",         displayName: "Strawberry Field",       completionMessage: "The sweetest things grow closest to the ground.",                              month: 7,  day: 25),
        Artwork(id: "tropicalFish",       fileName: "tropicalFish",       displayName: "Tropical Fish",          completionMessage: "The reef paints everything that swims through it.",                            month: 7,  day: 26),
        Artwork(id: "underwaterShipwreck",fileName:"underwaterShipwreck", displayName: "Underwater Shipwreck",   completionMessage: "Even what sinks becomes a home for something new.",                            month: 7,  day: 28),
        Artwork(id: "seahorse",           fileName: "seahorse",           displayName: "Seahorse",               completionMessage: "Slowness is its own kind of current.",                                        month: 7,  day: 29),

        // ── August — Late summer, ocean life ────────────────────────

        Artwork(id: "blueJelly",          fileName: "blueJelly",          displayName: "Blue Jellyfish",         completionMessage: "No bones, no brain, no plan — and still it glows.",                           month: 8,  day: 1),
        Artwork(id: "lanternFestival",   fileName: "lanternFestival",    displayName: "Lantern Festival",       completionMessage: "Each light carries a wish the sky was kind enough to hold.",                    month: 8,  day: 2),
        Artwork(id: "sealOnRock",         fileName: "sealOnRock",         displayName: "Seal on a Rock",         completionMessage: "The rock is warm and the horizon is wide — what else could matter.",             month: 8,  day: 3),
        Artwork(id: "mantaRay",           fileName: "mantaRay",           displayName: "Manta Ray",              completionMessage: "The widest wings belong to the quietest flyer.",                               month: 8,  day: 4),
        Artwork(id: "ospreyDive",         fileName: "ospreyDive",         displayName: "Osprey Dive",            completionMessage: "The best fisherman never touches the water twice.",                            month: 8,  day: 5),
        Artwork(id: "whaleTailOcean",     fileName: "whaleTailOcean",     displayName: "Whale Tail",             completionMessage: "The tail says goodbye to the surface but the whale always comes back.",          month: 8,  day: 6),
        Artwork(id: "humpbackWhale",      fileName: "humpbackWhale",      displayName: "Humpback Whale",         completionMessage: "Breaking the surface is just the ocean exhaling through something enormous.",  month: 8,  day: 7),
        Artwork(id: "wheatFieldGoldenHour",fileName:"wheatFieldGoldenHour",displayName:"Wheat Field at Golden Hour",completionMessage: "The field bows to the sun because it has nothing left to hold.",              month: 8,  day: 8),
        Artwork(id: "slothRainforest",    fileName: "slothRainforest",    displayName: "Sloth in Rainforest",    completionMessage: "Moving slowly is not the same as standing still.",                             month: 8,  day: 9),
        Artwork(id: "seaOtter",           fileName: "seaOtter",           displayName: "Sea Otter",              completionMessage: "Floating is easy when you hold onto what matters.",                            month: 8,  day: 10),
        Artwork(id: "dolphinLeaping",     fileName: "dolphinLeaping",     displayName: "Dolphin Leaping",        completionMessage: "Joy doesn't need a reason. It just needs a surface to break.",                month: 8,  day: 13),
        Artwork(id: "fountain",           fileName: "fountain",           displayName: "Market Fountain",        completionMessage: "The fountain gives the same water to pigeons and poets alike.",                 month: 8,  day: 14),
        Artwork(id: "fishingTrawler",     fileName: "fishingTrawler",     displayName: "Fishing Trawler",        completionMessage: "The nets go out empty and come back full of faith.",                           month: 8,  day: 15),
        Artwork(id: "mountainRowboat",    fileName: "mountainRowboat",    displayName: "Mountain Rowboat",       completionMessage: "A boat tied to a dock is still dreaming of the far shore.",                    month: 8,  day: 16),
        Artwork(id: "kelpForest",          fileName: "kelpForest",          displayName: "Kelp Forest",            completionMessage: "The tallest forests grow where the sun must swim to reach them.",               month: 8,  day: 18),
        Artwork(id: "pelicanColorful",    fileName: "pelicanColorful",    displayName: "Pelican",                completionMessage: "The biggest catch fits in the smallest moment of patience.",                   month: 8,  day: 19),
        Artwork(id: "moonlitHarbor",      fileName: "moonlitHarbor",      displayName: "Moonlit Harbor",         completionMessage: "The harbor glows differently when only the moon is watching.",                  month: 8,  day: 20),
        Artwork(id: "stormPetrelSea",     fileName: "stormPetrelSea",     displayName: "Storm Petrel at Sea",    completionMessage: "The smallest seabird dances on the waves the storm forgot to flatten.",          month: 8,  day: 21),
        Artwork(id: "alpineMeadow",       fileName: "alpineMeadow",       displayName: "Alpine Meadow",          completionMessage: "The wildflowers bloom without knowing anyone is watching.",                     month: 8,  day: 22),
        Artwork(id: "desertMesa",         fileName: "desertMesa",         displayName: "Desert Mesa",            completionMessage: "The mesa stands because erosion forgot to take everything.",                   month: 8,  day: 23),
        Artwork(id: "grizzlySalmon",     fileName: "grizzlySalmon",      displayName: "Grizzly Bear Fishing",  completionMessage: "The river gives to whoever stands still long enough.",                          month: 8,  day: 25),
        Artwork(id: "pingFlamingo",       fileName: "pingFlamingo",       displayName: "Flamingo Pair",          completionMessage: "Pink is just confidence wearing feathers.",                                    month: 8,  day: 26),
        Artwork(id: "pirateShip",        fileName: "pirateShip",         displayName: "Pirate Ship",            completionMessage: "The skull and crossbones fly because someone chose the horizon over the harbor.", month: 8, day: 27),
        Artwork(id: "jelly",              fileName: "jelly",              displayName: "Jellyfish",              completionMessage: "Drifting is a decision the current made for both of you.",                     month: 8,  day: 29),

        // ── September — Transition, birds ───────────────────────────

        Artwork(id: "baldEagle",          fileName: "baldEagle",          displayName: "Bald Eagle",             completionMessage: "The highest branches belong to whoever refuses to look away.",                 month: 9,  day: 1),
        Artwork(id: "stargazingCampfire",fileName:"stargazingCampfire",  displayName: "Stargazing Campfire",    completionMessage: "The fire keeps you warm. The stars keep you wondering.",                        month: 9,  day: 2),
        Artwork(id: "coastalTidePools",   fileName: "coastalTidePools",   displayName: "Coastal Tide Pools",     completionMessage: "The ocean leaves small gifts in every hollow it finds.",                        month: 9,  day: 3),
        Artwork(id: "saltFlatSolitude",   fileName: "saltFlatSolitude",   displayName: "Salt Flat Solitude",     completionMessage: "The flattest land holds the biggest sky.",                                      month: 9,  day: 4),
        Artwork(id: "coastalCliffs",      fileName: "coastalCliffs",      displayName: "Coastal Cliffs",         completionMessage: "The lighthouse asks nothing of the ships. It just stays lit.",                 month: 9,  day: 5),
        Artwork(id: "eagleSouring",       fileName: "eagleSouring",       displayName: "Soaring Eagle",          completionMessage: "The wind does the lifting. The wings do the trusting.",                        month: 9,  day: 7),
        Artwork(id: "pandaBamboo",       fileName: "pandaBamboo",        displayName: "Panda in Bamboo",       completionMessage: "The bamboo grows around the panda, or maybe it's the other way.",              month: 9,  day: 9),
        Artwork(id: "moroccanSouk",       fileName: "moroccanSouk",       displayName: "Moroccan Souk",          completionMessage: "The narrowest alleys hold the richest colors.",                                month: 9,  day: 10),
        Artwork(id: "observatory",        fileName: "observatory",        displayName: "Observatory",            completionMessage: "The dome opens for anyone willing to stay up past the stars.",                 month: 9,  day: 11),
        Artwork(id: "parrot",             fileName: "parrot",             displayName: "Parrot",                 completionMessage: "The brightest voice in the forest has nothing to prove.",                      month: 9,  day: 13),
        Artwork(id: "candyShop",          fileName: "candyShop",          displayName: "Candy Shop",             completionMessage: "The sweetest things are always behind glass, waiting to be chosen.",            month: 9,  day: 14),
        Artwork(id: "veniceCanalDusk",    fileName: "veniceCanalDusk",    displayName: "Venice Canal at Dusk",   completionMessage: "The city settles into the water and the water holds it gently.",                month: 9,  day: 15),
        Artwork(id: "twoParrots",         fileName: "twoParrots",         displayName: "Two Parrots",            completionMessage: "Conversation is just color with a heartbeat.",                                month: 9,  day: 16),
        Artwork(id: "japanesePagoda",     fileName: "japanesePagoda",     displayName: "Japanese Pagoda",        completionMessage: "Each tier lifts the next a little closer to the clouds.",                      month: 9,  day: 18),
        Artwork(id: "cathedralInterior",  fileName: "cathedralInterior",  displayName: "Cathedral Interior",     completionMessage: "Light through old glass falls on everyone the same.",                          month: 9,  day: 19),
        Artwork(id: "clockworkGears",    fileName: "clockworkGears",    displayName: "Clockwork Gears",       completionMessage: "Every small turn moves something larger than itself.",                         month: 9,  day: 20),
        Artwork(id: "romanAqueduct",      fileName: "romanAqueduct",      displayName: "Roman Aqueduct",         completionMessage: "The arches carry water the way memory carries what once mattered.",            month: 9,  day: 21),
        Artwork(id: "watchTower",         fileName: "watchTower",         displayName: "Lighthouse Keeper",      completionMessage: "Someone climbs the spiral every night so the ships don't have to wonder.",     month: 9,  day: 22),
        Artwork(id: "toucanPerched",      fileName: "toucanPerched",      displayName: "Toucan",                 completionMessage: "The beak carries more color than the branch can hold.",                       month: 9,  day: 23),
        Artwork(id: "medievalClockTower",fileName:"medievalClockTower",  displayName: "Medieval Clock Tower",   completionMessage: "The tower counts the hours for a town that stopped rushing long ago.",          month: 9,  day: 24),
        Artwork(id: "potteryWorkshop",    fileName: "potteryWorkshop",    displayName: "Pottery Workshop",       completionMessage: "The wheel turns and the clay remembers what your hands forgot.",               month: 9,  day: 26),
        Artwork(id: "roadrunner",         fileName: "roadrunner",         displayName: "Roadrunner",             completionMessage: "Speed only matters when you know where the dust settles.",                     month: 9,  day: 29),

        // ── October — Peak autumn ───────────────────────────────────

        Artwork(id: "moose",              fileName: "moose",              displayName: "Moose",                  completionMessage: "The forest makes room for anything that walks slowly enough.",                 month: 10, day: 1),
        Artwork(id: "mushroomForest",    fileName: "mushroomForest",     displayName: "Mushroom Forest",        completionMessage: "The forest floor hides its brightest colors under the oldest trees.",           month: 10, day: 2),
        Artwork(id: "ancientRuins",       fileName: "ancientRuins",       displayName: "Ancient Ruins",          completionMessage: "The jungle reclaims what was never really taken from it.",                     month: 10, day: 3),
        Artwork(id: "autumnOrchard",      fileName: "autumnOrchard",      displayName: "Autumn Orchard",         completionMessage: "The tree gives its fruit to whatever hand shows up in autumn.",                month: 10, day: 5),
        Artwork(id: "compassMap",         fileName: "compassMap",         displayName: "Compass & Old Map",      completionMessage: "The compass points forward. The map remembers where you've been.",              month: 10, day: 6),
        Artwork(id: "mountainGoat",       fileName: "mountainGoat",       displayName: "Mountain Goat",          completionMessage: "The ledge was never as narrow as it looked from below.",                       month: 10, day: 7),
        Artwork(id: "forestPuddleLeaves",fileName:"forestPuddleLeaves", displayName: "Forest Puddle Leaves",  completionMessage: "The puddle collects what the trees were ready to release.",                     month: 10, day: 8),
        Artwork(id: "gazelleSavanna",     fileName: "gazelleSavanna",     displayName: "Gazelle",                completionMessage: "Grace is just fear that learned how to leap.",                                 month: 10, day: 9),
        Artwork(id: "autumnBarn",        fileName: "autumnBarn",          displayName: "Autumn Barn",           completionMessage: "The barn holds the harvest like a promise it made to the field.",               month: 10, day: 10),
        Artwork(id: "redCoveredBridge",   fileName: "redCoveredBridge",   displayName: "Red Covered Bridge",     completionMessage: "The bridge wears red so you never lose your way home.",                        month: 10, day: 12),
        Artwork(id: "sleepyFox",          fileName: "sleepyFox",          displayName: "Sleepy Fox",             completionMessage: "Rest is the bravest thing a wild thing can do.",                               month: 10, day: 13),
        Artwork(id: "birchTreesAutumn",   fileName: "birchTreesAutumn",   displayName: "Birch Trees in Autumn",  completionMessage: "The white bark holds still while everything golden lets go.",                   month: 10, day: 14),
        Artwork(id: "bison",              fileName: "bison",              displayName: "Bison",                  completionMessage: "The prairie parts for what refuses to go around.",                             month: 10, day: 15),
        Artwork(id: "tigerStalking",      fileName: "tigerStalking",      displayName: "Tiger",                  completionMessage: "Stripes are just the jungle remembering where the light fell.",               month: 10, day: 18),
        Artwork(id: "redFoxAutumn",       fileName: "redFoxAutumn",       displayName: "Red Fox in Autumn",      completionMessage: "The leaves fall and the fox stays — both exactly where they belong.",            month: 10, day: 20),
        Artwork(id: "scottishHighlands",  fileName: "scottishHighlands",  displayName: "Scottish Highlands",     completionMessage: "The ruins stay because the stone has nowhere else to be.",                     month: 10, day: 21),
        Artwork(id: "bridgeAutumn",       fileName: "bridgeAutumn",       displayName: "Covered Bridge Autumn",  completionMessage: "The bridge blushes when the trees change around it.",                          month: 10, day: 23),
        Artwork(id: "purpleMoose",        fileName: "purpleMoose",        displayName: "Purple Moose",           completionMessage: "Some colors exist only because someone imagined them.",                        month: 10, day: 24),
        Artwork(id: "autumnBench",        fileName: "autumnBench",        displayName: "Autumn Bench",           completionMessage: "The bench waits for no one, yet holds a place for everyone.",                  month: 10, day: 27),
        Artwork(id: "paperBoat",          fileName: "paperBoat",          displayName: "Paper Boat",             completionMessage: "The smallest vessel carries the biggest imagination.",                         month: 10, day: 28),
        Artwork(id: "autumnForestPath",  fileName: "autumnForestPath",   displayName: "Autumn Forest Path",    completionMessage: "The path doesn't end. It just changes what it's covered with.",                month: 10, day: 29),
        Artwork(id: "birdFish",           fileName: "birdFish",           displayName: "Bird and Fish",          completionMessage: "They meet where the water ends and the air begins.",                          month: 10, day: 30),
        Artwork(id: "bioluminescentBay", fileName: "bioluminescentBay",  displayName: "Bioluminescent Bay",     completionMessage: "The water remembers the stars long after the sky forgets.",                     month: 10, day: 31),

        // ── November — Deep autumn, earth and warmth ────────────────

        Artwork(id: "gorilla",            fileName: "gorilla",            displayName: "Gorilla",                completionMessage: "Strength sits quietly until the forest needs it.",                             month: 11, day: 1),
        Artwork(id: "crystalCave",       fileName: "crystalCave",        displayName: "Crystal Cave",           completionMessage: "The earth grows its own light when no one is looking.",                         month: 11, day: 2),
        Artwork(id: "giantPanda",         fileName: "giantPanda",         displayName: "Giant Panda",            completionMessage: "The gentlest giants eat the simplest meals.",                                  month: 11, day: 4),
        Artwork(id: "rainyParis",         fileName: "rainyParis",         displayName: "Rainy Paris",            completionMessage: "The city shines brightest when the sky gives it something to reflect.",        month: 11, day: 7),
        Artwork(id: "sushiBar",           fileName: "sushiBar",           displayName: "Sushi Bar",              completionMessage: "The sharpest knife makes the gentlest cut.",                                   month: 11, day: 8),
        Artwork(id: "koala",              fileName: "koala",              displayName: "Koala",                  completionMessage: "Napping is an art when you've found the right branch.",                        month: 11, day: 10),
        Artwork(id: "deadTreesLakeFog",   fileName: "deadTreesLakeFog",   displayName: "Lake in Fog",            completionMessage: "The trees gave up their leaves but kept their reflections.",                    month: 11, day: 11),
        Artwork(id: "cobblestoneAlley",   fileName: "cobblestoneAlley",   displayName: "Cobblestone Alley",      completionMessage: "Every stone was placed by someone who never saw the cafe lights.",             month: 11, day: 13),
        Artwork(id: "bakeryInterior",    fileName: "bakeryInterior",     displayName: "French Bakery",          completionMessage: "The bread rises in the dark and fills the room with warmth by morning.",        month: 11, day: 14),
        Artwork(id: "terracedVineyard",   fileName: "terracedVineyard",   displayName: "Terraced Vineyard",      completionMessage: "The hill was too steep until someone decided to build steps for grapes.",      month: 11, day: 16),
        Artwork(id: "alpacas",            fileName: "alpacas",            displayName: "Alpacas",                completionMessage: "The softest wool comes from the most patient animals.",                        month: 11, day: 19),
        Artwork(id: "stoneArchBridge",    fileName: "stoneArchBridge",    displayName: "Stone Arch Bridge",      completionMessage: "The arch holds because every stone leans on its neighbor.",                    month: 11, day: 22),
        Artwork(id: "ravensBirch",       fileName: "ravensBirch",        displayName: "Ravens on Birch",       completionMessage: "Two dark shapes on white bark — winter's own calligraphy.",                    month: 11, day: 24),
        Artwork(id: "racoonLake",         fileName: "racoonLake",         displayName: "Raccoon at the Lake",    completionMessage: "Curiosity washes everything twice, just to be sure.",                          month: 11, day: 26),
        Artwork(id: "cactusGarden",       fileName: "cactusGarden",       displayName: "Cactus Garden",          completionMessage: "The driest soil grows the most patient beauty.",                               month: 11, day: 28),
        Artwork(id: "chameleo",           fileName: "chameleo",           displayName: "Chameleon",              completionMessage: "Changing color isn't hiding. It's listening to the room.",                     month: 11, day: 30),

        // ── December — Winter returns, wonder ───────────────────────

        Artwork(id: "cardinalHolly",     fileName: "cardinalHolly",     displayName: "Cardinal on Holly",      completionMessage: "The red bird and the red berry share the same winter secret.",                  month: 12, day: 1),
        Artwork(id: "christmasWreath",   fileName: "christmasWreath",   displayName: "Christmas Wreath",       completionMessage: "The circle says welcome without ever opening.",                                month: 12, day: 3),
        Artwork(id: "foxSleepingSnow",   fileName: "foxSleepingSnow",   displayName: "Fox Sleeping in Snow",   completionMessage: "The snow covers everything except what's already warm.",                       month: 12, day: 5),
        Artwork(id: "gingerbreadHouse",  fileName: "gingerbreadHouse",  displayName: "Gingerbread House",     completionMessage: "The sweetest architecture melts on the tongue, not in the rain.",              month: 12, day: 7),
        Artwork(id: "gingerbreadHouseSnow",fileName:"gingerbreadHouseSnow",displayName:"Gingerbread House Snow",completionMessage: "The frosting falls heavier outdoors, but tastes the same.",                   month: 12, day: 8),
        Artwork(id: "menorahWindow",     fileName: "menorahWindow",     displayName: "Menorah in Window",      completionMessage: "Each flame remembers the one that came before it.",                            month: 12, day: 9),
        Artwork(id: "toyWorkshop",        fileName: "toyWorkshop",        displayName: "Toy Workshop",           completionMessage: "The smallest hands build the biggest smiles.",                                 month: 12, day: 10),
        Artwork(id: "snowmanTwilight",   fileName: "snowmanTwilight",   displayName: "Snowman at Twilight",    completionMessage: "The twilight gives the snowman one last shadow before morning.",               month: 12, day: 11),
        Artwork(id: "fireplaceStockings",fileName:"fireplaceStockings", displayName: "Fireplace Stockings",   completionMessage: "The fire crackles stories it learned from the wood.",                          month: 12, day: 13),
        Artwork(id: "snowGlobe",          fileName: "snowGlobe",          displayName: "Snow Globe",             completionMessage: "The whole world fits inside if you shake it gently enough.",                    month: 12, day: 16),
        Artwork(id: "christmasMarketNight",fileName:"christmasMarketNight",displayName:"Christmas Market Night",completionMessage: "The brightest stalls are the ones that stay open past the cold.",              month: 12, day: 17),
        Artwork(id: "hotCocoaMug",       fileName: "hotCocoaMug",       displayName: "Hot Cocoa Mug",          completionMessage: "The warmth begins at the rim and works its way in.",                           month: 12, day: 20),
        Artwork(id: "winterSleigh",      fileName: "winterSleigh",       displayName: "Winter Sleigh",         completionMessage: "The lantern swings because the path ahead is worth lighting.",                 month: 12, day: 24),
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
