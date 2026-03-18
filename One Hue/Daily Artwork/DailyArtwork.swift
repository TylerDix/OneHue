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

    /// 366 artworks ordered chronologically (Jan → Dec).
    /// Each artwork anchors to a specific (month, day) and remains the
    /// daily artwork until the next entry's date arrives.
    /// Placement reflects seasonal imagery, cultural resonance, and the
    /// rhythm of the natural world — without endorsing specific holidays.
    static let catalog: [Artwork] = [

                // ── January — Deep winter, fresh start ──────────────────────

        Artwork(id: "snowyOwlPerch",     fileName: "snowyOwlPerch",     displayName: "Snowy Owl Perch",        completionMessage: "The frost-covered post is a throne for whoever waits longest.",                 month: 1,  day: 1),
        Artwork(id: "polarBearMother",   fileName: "polarBearMother",   displayName: "Polar Bear Mother",      completionMessage: "The smallest paws follow the largest across the endless white.",               month: 1,  day: 2),
        Artwork(id: "penguins",           fileName: "penguins",           displayName: "Penguins",               completionMessage: "They huddle not because they're cold, but because they choose each other.",    month: 1,  day: 3),
        Artwork(id: "ermineSnow",         fileName: "ermineSnow",         displayName: "Ermine in Snow",         completionMessage: "The smallest hunter wears the whitest coat.",                                   month: 1,  day: 4),
        Artwork(id: "icicleCave",        fileName: "icicleCave",        displayName: "Icicle Cave",            completionMessage: "The cave hangs its chandeliers for whoever dares to enter.",                    month: 1,  day: 5),
        Artwork(id: "iceSkaters",          fileName: "iceSkaters",          displayName: "Ice Skaters",            completionMessage: "The ice holds everyone who trusts it enough to glide.",                        month: 1,  day: 6),
        Artwork(id: "snowCabin",          fileName: "snowCabin",          displayName: "Snow Cabin",             completionMessage: "The deepest snow falls quietest around the places that glow.",                month: 1,  day: 7),
        Artwork(id: "dogSledTeam",        fileName: "dogSledTeam",        displayName: "Dog Sled Team",          completionMessage: "The trail is only as strong as the trust between the lead dog and the last.",  month: 1,  day: 8),
        Artwork(id: "arcticFox",          fileName: "arcticFox",          displayName: "Arctic Fox",             completionMessage: "Some things survive by blending in. Others, by simply enduring.",              month: 1,  day: 9),
        Artwork(id: "iceFishingShanty",  fileName: "iceFishingShanty",  displayName: "Ice Fishing Shanty",     completionMessage: "Color stands out bravest on a frozen lake.",                                    month: 1,  day: 10),
        Artwork(id: "mooseAtTwilight",   fileName: "mooseAtTwilight",   displayName: "Moose at Twilight",      completionMessage: "The biggest silhouette moves softest through the purple hour.",                 month: 1,  day: 11),
        Artwork(id: "owl",                fileName: "owl",                displayName: "Owl",                    completionMessage: "Wisdom is just patience that learned to sit in the dark.",                     month: 1,  day: 12),
        Artwork(id: "arcticFoxSnow",      fileName: "arcticFoxSnow",      displayName: "Arctic Fox in Snow",     completionMessage: "The fox sleeps deepest where the snow erases all paths.",                       month: 1,  day: 13),
        Artwork(id: "chineseNewYearDragon",fileName:"chineseNewYearDragon",displayName:"Chinese New Year Dragon",completionMessage: "The dragon dances because the new year needs reminding that joy is loud.",     month: 1,  day: 14),
        Artwork(id: "staveChurch",        fileName: "staveChurch",        displayName: "Stave Church",           completionMessage: "The oldest timber still holds the shape of someone's prayer.",                  month: 1,  day: 15),
        Artwork(id: "chickadeeWinterberry",fileName:"chickadeeWinterberry",displayName: "Chickadee on Winterberry",completionMessage: "The smallest songs carry the farthest in frozen air.",                         month: 1,  day: 16),
        Artwork(id: "polarExpressTrain",  fileName: "polarExpressTrain",  displayName: "Polar Express Train",    completionMessage: "The train only stops for those who still believe in the journey.",             month: 1,  day: 17),
        Artwork(id: "cozyCabin",          fileName: "cozyCabin",          displayName: "Cozy Cabin",             completionMessage: "The warmest rooms are the ones that expect nothing.",                          month: 1,  day: 18),
        Artwork(id: "foggyDock",         fileName: "foggyDock",         displayName: "Foggy Dock",             completionMessage: "The planks vanish into white, but they still hold your weight.",                month: 1,  day: 19),
        Artwork(id: "barnOwlHunting",    fileName: "barnOwlHunting",    displayName: "Barn Owl Hunting",       completionMessage: "The silent wings read the snow like a letter from the field.",                  month: 1,  day: 20),
        Artwork(id: "fishUnderIce",       fileName: "fishUnderIce",       displayName: "Fish Under Ice",         completionMessage: "Beneath the stillness, life keeps its own quiet rhythm.",                       month: 1,  day: 21),
        Artwork(id: "snowLeopard",         fileName: "snowLeopard",         displayName: "Snow Leopard",           completionMessage: "The ghost of the mountain moves without leaving a trace.",                      month: 1,  day: 22),
        Artwork(id: "owlCornfieldMoon",  fileName: "owlCornfieldMoon",  displayName: "Owl at Moonrise",        completionMessage: "The owl sits still because the moon already said everything.",                   month: 1,  day: 23),
        Artwork(id: "rooftopCellist",    fileName: "rooftopCellist",    displayName: "Rooftop Cellist",        completionMessage: "The melody climbs higher than the rooftops, searching for someone awake.",      month: 1,  day: 24),
        Artwork(id: "snowyOwlField",    fileName: "snowyOwlField",    displayName: "Snowy Owl in Field",     completionMessage: "The owl waits on the fencepost because the field always sends something.",     month: 1,  day: 25),
        Artwork(id: "walrus",             fileName: "walrus",             displayName: "Walrus",                 completionMessage: "Weight is its own kind of grace when you stop apologizing for it.",            month: 1,  day: 26),
        Artwork(id: "lighthouseCliffs",  fileName: "lighthouseCliffs",   displayName: "Lighthouse Cliffs",      completionMessage: "The light holds steady because the storm never asked permission.",             month: 1,  day: 27),
        Artwork(id: "snowFox",            fileName: "snowFox",            displayName: "Snow Fox",               completionMessage: "The white fur knows that stillness is the warmest shelter.",                    month: 1,  day: 28),
        Artwork(id: "arcticOceanIce",      fileName: "arcticOceanIce",      displayName: "Arctic Ocean Ice",              completionMessage: "The coldest water holds the bluest silence.",                                     month: 1,  day: 29),
        Artwork(id: "foggyCoastMorning",   fileName: "foggyCoastMorning",   displayName: "Foggy Coast Morning",           completionMessage: "The fog erases the horizon so the sea and sky can finally meet.",                 month: 1,  day: 30),
        Artwork(id: "deepSeaAbyss",        fileName: "deepSeaAbyss",        displayName: "Deep Sea Abyss",                completionMessage: "The deepest dark holds the strangest light.",                                     month: 1,  day: 31),

                // ── February — Winter continues, introspection ──────────────

        Artwork(id: "barnOwl",            fileName: "barnOwl",            displayName: "Barn Owl",               completionMessage: "The quietest wings carry the sharpest eyes.",                                  month: 2,  day: 1),
        Artwork(id: "barnAtDawn",         fileName: "barnAtDawn",         displayName: "Barn at Dawn",           completionMessage: "The rooster crows and the barn answers with the smell of hay.",                month: 2,  day: 2),
        Artwork(id: "rowboatLilyPond",   fileName: "rowboatLilyPond",   displayName: "Rowboat on Lily Pond",   completionMessage: "The boat drifts because the pond already knows where it belongs.",               month: 2,  day: 3),
        Artwork(id: "mountainHotSpring", fileName: "mountainHotSpring", displayName: "Mountain Hot Spring",    completionMessage: "The earth offers its warmth where the snow presses hardest.",                   month: 2,  day: 4),
        Artwork(id: "swanLakeValentine", fileName: "swanLakeValentine", displayName: "Swan Lake Valentine",    completionMessage: "Two necks bend into a shape the heart already knew.",                           month: 2,  day: 5),
        Artwork(id: "mapleSyrupTapping", fileName: "mapleSyrupTapping", displayName: "Maple Syrup Tapping",    completionMessage: "The sweetest sap runs when winter finally loosens its grip.",                   month: 2,  day: 6),
        Artwork(id: "penguinColony",     fileName: "penguinColony",     displayName: "Penguin Colony",         completionMessage: "The huddle holds because every body shares the same cold.",                    month: 2,  day: 7),
        Artwork(id: "hibernatingHedgehog",fileName:"hibernatingHedgehog", displayName: "Hibernating Hedgehog",  completionMessage: "The deepest sleep belongs to those who trust the thaw will come.",              month: 2,  day: 8),
        Artwork(id: "owlFamily",          fileName: "owlFamily",          displayName: "Owl Family",             completionMessage: "Family is a branch that holds more than it was meant to.",                     month: 2,  day: 9),
        Artwork(id: "deerBirchGrove",    fileName: "deerBirchGrove",    displayName: "Deer in Birch Grove",    completionMessage: "White bark and white tail — the forest keeps its own camouflage.",              month: 2,  day: 10),
        Artwork(id: "winterGreenhouse",   fileName: "winterGreenhouse",   displayName: "Winter Greenhouse",      completionMessage: "The glass holds summer hostage while winter presses its face against the pane.",month: 2,  day: 11),
        Artwork(id: "crossCountrySkier", fileName: "crossCountrySkier",  displayName: "Cross-Country Skier",    completionMessage: "The tracks behind you are proof the forest let you through.",                   month: 2,  day: 12),
        Artwork(id: "coveredBridge",      fileName: "coveredBridge",      displayName: "Covered Bridge",         completionMessage: "Some crossings are worth protecting from the weather.",                        month: 2,  day: 13),
        Artwork(id: "lunarLanterns",     fileName: "lunarLanterns",     displayName: "Lunar Lanterns",         completionMessage: "Red and gold carry every wish the old year left behind.",                       month: 2,  day: 14),
        Artwork(id: "mardiGrasMasks",     fileName: "mardiGrasMasks",     displayName: "Mardi Gras Masks",       completionMessage: "Behind every mask is someone who chose celebration over hiding.",               month: 2,  day: 15),
        Artwork(id: "hotSpring",          fileName: "hotSpring",          displayName: "Hot Spring",             completionMessage: "The earth offers warmth to anyone willing to sit with the cold.",              month: 2,  day: 16),
        Artwork(id: "robinSnowdrops",     fileName: "robinSnowdrops",     displayName: "Robin and Snowdrops",    completionMessage: "The first flowers and the first song arrive on the same morning.",              month: 2,  day: 17),
        Artwork(id: "stoneWatermill",     fileName: "stoneWatermill",     displayName: "Stone Watermill",        completionMessage: "The wheel turns because the water never stops giving.",                        month: 2,  day: 18),
        Artwork(id: "polarBearCub",      fileName: "polarBearCub",       displayName: "Polar Bear and Cub",    completionMessage: "The smallest footprints follow the biggest ones through the snow.",            month: 2,  day: 19),
        Artwork(id: "gondolaSkiLift",     fileName: "gondolaSkiLift",     displayName: "Gondola Ski Lift",       completionMessage: "The summit waits for those who trust the cable and the climb.",                 month: 2,  day: 20),
        Artwork(id: "frozenWaterfallBlue",fileName: "frozenWaterfallBlue",displayName: "Frozen Waterfall",       completionMessage: "Even the waterfall rests when winter asks it to.",                              month: 2,  day: 21),
        Artwork(id: "bisonYellowstone",  fileName: "bisonYellowstone",  displayName: "Bison in Yellowstone",   completionMessage: "The herd walks through steam because the earth still breathes here.",           month: 2,  day: 22),
        Artwork(id: "underwaterShipwreck",fileName:"underwaterShipwreck",displayName:"Underwater Shipwreck",  completionMessage: "What the sea takes, it slowly turns into a home for smaller things.",           month: 2,  day: 23),
        Artwork(id: "machuPicchuLlama",  fileName: "machuPicchuLlama",  displayName: "Machu Picchu Llama",    completionMessage: "The llama stands where empires crumbled, unbothered by history.",               month: 2,  day: 24),
        Artwork(id: "mountainLakeReflection", fileName: "mountainLakeReflection", displayName: "Mountain Lake Reflection", completionMessage: "The mountain only shows its true self to water that holds perfectly still.", month: 2, day: 25),
        Artwork(id: "lighthouseWinterStorm", fileName: "lighthouseWinterStorm", displayName: "Lighthouse in Storm", completionMessage: "The beam cuts through because the darkness never learned to dodge.",          month: 2,  day: 26),
        Artwork(id: "winterGardenGate",  fileName: "winterGardenGate",  displayName: "Winter Garden Gate",     completionMessage: "The gate stays open because the garden has nothing left to hide.",              month: 2,  day: 27),
        Artwork(id: "frozenPondFrog",    fileName: "frozenPondFrog",    displayName: "Frozen Pond Frog",       completionMessage: "The frog sits on the last lily pad, waiting for the ice to remember spring.",   month: 2,  day: 28),
        Artwork(id: "winterTownSnowman",fileName:"winterTownSnowman",displayName: "Winter Town Snowman",    completionMessage: "The snowman stands in the yard because someone believed in an extra day.",       month: 2,  day: 29),

                // ── March — Thaw, awakening ─────────────────────────────────

        Artwork(id: "hareSpringThaw",     fileName: "hareSpringThaw",     displayName: "Hare in Spring Thaw",    completionMessage: "The first brave thing to move after winter is always the smallest.",            month: 3,  day: 1),
        Artwork(id: "geeseMigration",     fileName: "geeseMigration",     displayName: "Geese Migration",        completionMessage: "The V holds because every bird trusts the one in front.",                       month: 3,  day: 2),
        Artwork(id: "robinNestBlossoms", fileName: "robinNestBlossoms", displayName: "Robin Nest in Blossoms", completionMessage: "The nest holds still while the blossoms fall around it like pink snow.",         month: 3,  day: 3),
        Artwork(id: "cozyCabinSmoke",    fileName: "cozyCabinSmoke",    displayName: "Cabin Smoke",            completionMessage: "The chimney speaks in gray curls to a sky that always listens.",                month: 3,  day: 4),
        Artwork(id: "rockyCoastline",     fileName: "rockyCoastline",     displayName: "Rocky Coastline",        completionMessage: "The rocks don't fight the waves. They just remember what they are.",           month: 3,  day: 5),
        Artwork(id: "cherryBlossom",      fileName: "cherryBlossom",      displayName: "Cherry Blossoms",        completionMessage: "Beauty that stays forever would forget how to be beautiful.",                  month: 3,  day: 6),
        Artwork(id: "frozenCascade",     fileName: "frozenWaterfall",    displayName: "Frozen Cascade",        completionMessage: "The water remembers how to fall, even when it's standing still.",              month: 3,  day: 7),
        Artwork(id: "penguinFam",         fileName: "penguinFam",         displayName: "Penguin Family",         completionMessage: "The coldest place on earth still has the warmest huddles.",                    month: 3,  day: 8),
        Artwork(id: "ottersThawingRiver", fileName: "ottersThawingRiver", displayName: "Otters on a Thawing River",completionMessage: "Play is how the river remembers it's allowed to move again.",                 month: 3,  day: 9),
        Artwork(id: "springLambsDawn",   fileName: "springLambsDawn",   displayName: "Spring Lambs at Dawn",   completionMessage: "New legs learn the meadow one wobble at a time.",                               month: 3,  day: 10),
        Artwork(id: "cranePink",          fileName: "cranePink",          displayName: "Pink Crane",             completionMessage: "Balance is easier when you stop looking down.",                                month: 3,  day: 11),
        Artwork(id: "kingfisher",         fileName: "kingfisher",         displayName: "Kingfisher",             completionMessage: "Patience looks effortless from the branch above.",                             month: 3,  day: 12),
        Artwork(id: "vikingLongship",     fileName: "vikingLongship",     displayName: "Viking Longship",        completionMessage: "The dragon prow parts the fog so the crew doesn't have to fear it.",           month: 3,  day: 13),
        Artwork(id: "japaneseGarden",    fileName: "japaneseGarden",    displayName: "Japanese Garden",        completionMessage: "Every stone was placed to look as though no one placed it.",                    month: 3,  day: 14),
        Artwork(id: "deerDrinking",       fileName: "deerDrinking",       displayName: "Deer at the Stream",     completionMessage: "The clearest water reflects whoever is brave enough to lean in.",              month: 3,  day: 15),
        Artwork(id: "greenhouseSeedlings",fileName:"greenhouseSeedlings",displayName:"Greenhouse Seedlings",  completionMessage: "Every row of dirt is a promise the gardener makes to April.",                   month: 3,  day: 16),
        Artwork(id: "kiteFestival",       fileName: "kiteFestival",       displayName: "Kite Festival",          completionMessage: "The string only matters to the one holding it. The kite already knows the wind.", month: 3, day: 17),
        Artwork(id: "wisteriaFlowers",    fileName: "wisteriaFlowers",    displayName: "Wisteria",               completionMessage: "The heaviest blooms hang from the thinnest branches.",                         month: 3,  day: 18),
        Artwork(id: "cherryBlossomTemple",fileName:"cherryBlossomTemple",displayName:"Cherry Blossom Temple",  completionMessage: "The petals fall without deciding to — and that is what makes them beautiful.",   month: 3,  day: 19),
        Artwork(id: "porcupine",          fileName: "porcupine",          displayName: "Porcupine",              completionMessage: "The softest hearts build the sharpest defenses.",                              month: 3,  day: 20),
        Artwork(id: "iceCave",            fileName: "iceCave",            displayName: "Ice Cave",               completionMessage: "The light finds a way in, even through something frozen solid.",               month: 3,  day: 21),
        Artwork(id: "wisteriaArbor",      fileName: "wisteriaArbor",      displayName: "Wisteria Arbor",         completionMessage: "Some things grow best when they have something to lean on.",                   month: 3,  day: 22),
        Artwork(id: "redwoodCathedral",   fileName: "redwoodCathedral",   displayName: "Redwood Cathedral",      completionMessage: "The oldest trees hold the light without grasping.",                            month: 3,  day: 23),
        Artwork(id: "seaTurtleCoral",   fileName: "seaTurtleCoral",   displayName: "Sea Turtle Reef",        completionMessage: "The turtle swims through the coral like a slow breath the reef keeps taking.",   month: 3,  day: 24),
        Artwork(id: "stargazerTelescope",fileName:"stargazerTelescope",displayName:"Stargazer Telescope",    completionMessage: "The lens finds nothing new — only what has been waiting to be seen.",            month: 3,  day: 25),
        Artwork(id: "bicycleHoneysuckle",fileName:"bicycleHoneysuckle",displayName:"Bicycle & Honeysuckle",  completionMessage: "The bike leans into the blossoms because the ride can wait.",                    month: 3,  day: 26),
        Artwork(id: "ravenFoggyValley",  fileName: "ravenFoggyValley",  displayName: "Raven in Foggy Valley",  completionMessage: "The raven sees through the fog because it never expected clarity.",             month: 3,  day: 27),
        Artwork(id: "wildflowerHillside",  fileName: "wildflowerHillside",  displayName: "Wildflower Hillside",           completionMessage: "The hillside blooms without asking if anyone is looking.",                        month: 3,  day: 28),
        Artwork(id: "mistyMountainPines",  fileName: "mistyMountainPines",  displayName: "Misty Mountain Pines",          completionMessage: "The pines stand in fog because they learned patience from the clouds.",           month: 3,  day: 29),
        Artwork(id: "foxGardenArbor",      fileName: "foxGardenArbor",      displayName: "Fox in the Garden",             completionMessage: "The fox curls up under the arbor because the flowers already kept watch.",        month: 3,  day: 30),
        Artwork(id: "estuaryGoldenHour",   fileName: "estuaryGoldenHour",   displayName: "Estuary Golden Hour",           completionMessage: "The estuary glows because the sun saves its warmest light for the water.",        month: 3,  day: 31),

                // ── April — Full spring, blossoms ───────────────────────────

        Artwork(id: "peacockBlue",        fileName: "peacockBlue",        displayName: "Peacock",                completionMessage: "The display isn't for you. It's for the one who sees it anyway.",              month: 4,  day: 1),
        Artwork(id: "rainforestWaterfall",fileName:"rainforestWaterfall",displayName:"Rainforest Waterfall",   completionMessage: "The jungle hides its loudest wonder behind the quietest green.",               month: 4,  day: 2),
        Artwork(id: "redPanda",            fileName: "redPanda",            displayName: "Red Panda",              completionMessage: "The quietest climber finds the sweetest branch.",                              month: 4,  day: 3),
        Artwork(id: "wolfMoonlight",     fileName: "wolfMoonlight",      displayName: "Wolf in Moonlight",     completionMessage: "The moon doesn't answer. That's why the wolf keeps asking.",                   month: 4,  day: 4),
        Artwork(id: "butteryflyGarden",   fileName: "butteryflyGarden",   displayName: "Butterfly Garden",       completionMessage: "The garden doesn't chase the butterflies. It just blooms.",                    month: 4,  day: 5),
        Artwork(id: "windmillTulips",    fileName: "windmillTulips",     displayName: "Windmill & Tulips",      completionMessage: "The blades turn and the tulips nod — each answering the same wind.",            month: 4,  day: 6),
        Artwork(id: "beeGarden",           fileName: "beeGarden",           displayName: "Bee Garden",             completionMessage: "Every flower is a doorway only the smallest travelers know.",                   month: 4,  day: 7),
        Artwork(id: "hummingbird",        fileName: "hummingbird",        displayName: "Hummingbird",            completionMessage: "Hovering takes more strength than flying ever could.",                         month: 4,  day: 8),
        Artwork(id: "hillsideVillage",    fileName: "hillsideVillage",    displayName: "Hillside Village",       completionMessage: "The houses climb because the view is worth the stairs.",                       month: 4,  day: 9),
        Artwork(id: "samuraiGarden",      fileName: "samuraiGarden",      displayName: "Samurai Garden",         completionMessage: "The warrior rests where the blossoms fall without fighting.",                   month: 4,  day: 10),
        Artwork(id: "libraryRoom",        fileName: "libraryRoom",        displayName: "Library Room",           completionMessage: "Every unread book is a conversation waiting to begin.",                        month: 4,  day: 11),
        Artwork(id: "veniceGondola",     fileName: "veniceGondola",     displayName: "Venice Gondola",         completionMessage: "The water remembers every oar stroke, then forgets.",                          month: 4,  day: 12),
        Artwork(id: "harborRowboats",     fileName: "harborRowboats",     displayName: "Harbor Rowboats",        completionMessage: "The boats rest together because the harbor holds them all the same.",          month: 4,  day: 13),
        Artwork(id: "venetianCanal",      fileName: "venetianCanal",      displayName: "Venetian Canal",         completionMessage: "Even still water knows where it's going.",                                     month: 4,  day: 14),
        Artwork(id: "storkNest",          fileName: "storkNest",          displayName: "Stork Nest",             completionMessage: "The chimney didn't ask for a family. The stork decided for it.",               month: 4,  day: 15),
        Artwork(id: "stoneArchCove",      fileName: "stoneArchCove",      displayName: "Stone Arch Cove",        completionMessage: "Stand small before something ancient. That's where perspective begins.",      month: 4,  day: 16),
        Artwork(id: "dragonfliesMeadow",  fileName: "dragonfliesMeadow",  displayName: "Dragonflies over Meadow",completionMessage: "They stitch the air above the water with invisible thread.",                   month: 4,  day: 17),
        Artwork(id: "wisteriaBridge",    fileName: "wisteriaBridge",    displayName: "Wisteria Bridge",        completionMessage: "The bridge wears purple because the vine chose beauty over speed.",             month: 4,  day: 18),
        Artwork(id: "koiPond",            fileName: "koiPond",            displayName: "Koi Pond",               completionMessage: "The fish don't know they're being watched. That's what makes them beautiful.",  month: 4,  day: 19),
        Artwork(id: "maroonTemple",       fileName: "maroonTemple",       displayName: "Pagoda Bridge",          completionMessage: "The bridge and the pagoda share the same reflection.",                         month: 4,  day: 20),
        Artwork(id: "firefliesGlowing",   fileName: "firefliesGlowing",   displayName: "Fireflies",              completionMessage: "A thousand small lights outshine anything that tries to burn alone.",          month: 4,  day: 21),
        Artwork(id: "harborLowTide",      fileName: "harborLowTide",      displayName: "Harbor at Low Tide",     completionMessage: "The tide always returns for what it left behind.",                              month: 4,  day: 22),
        Artwork(id: "bambooForestPath",   fileName: "bambooForestPath",   displayName: "Bamboo Forest",          completionMessage: "The tallest stalks grow by not looking at their neighbors.",                    month: 4,  day: 23),
        Artwork(id: "parisianCafe",      fileName: "parisianCafe",      displayName: "Parisian Café",          completionMessage: "The best conversations happen at tables too small for anything else.",          month: 4,  day: 24),
        Artwork(id: "gardenGateRoses",   fileName: "gardenGateRoses",    displayName: "Garden Gate",            completionMessage: "The gate is open because the roses already decided who belongs.",              month: 4,  day: 25),
        Artwork(id: "windmill",           fileName: "windmill",           displayName: "Windmill",               completionMessage: "It turns because it was built to face the wind, not hide from it.",            month: 4,  day: 26),
        Artwork(id: "wineCellar",         fileName: "wineCellar",         displayName: "Wine Cellar",            completionMessage: "Patience tastes better in the dark.",                                         month: 4,  day: 27),
        Artwork(id: "wisteriaPergola",   fileName: "wisteriaPergola",   displayName: "Wisteria Pergola",       completionMessage: "The pergola does nothing but stand still, and the wisteria thanks it in purple.", month: 4, day: 28),
        Artwork(id: "jadeMountainMist",    fileName: "jadeMountainMist",    displayName: "Jade Mountain Mist",            completionMessage: "The mountain disappears into the mist because some beauty prefers to be felt.",   month: 4,  day: 29),
        Artwork(id: "desertBloomSunset",   fileName: "desertBloomSunset",   displayName: "Desert Bloom Sunset",           completionMessage: "The desert blooms once and means it more than any garden ever could.",            month: 4,  day: 30),

                // ── May — Late spring, renewal ──────────────────────────────

        Artwork(id: "rowboatShallows",    fileName: "rowboatShallows",    displayName: "Rowboat in Shallows",    completionMessage: "The clearest water shows you everything the boat is resting on.",               month: 5,  day: 1),
        Artwork(id: "riceTerraces",       fileName: "riceTerraces",       displayName: "Rice Terraces",          completionMessage: "The mountain learned to hold water by letting people reshape it.",             month: 5,  day: 2),
        Artwork(id: "cappadociaBalloons", fileName: "cappadociaBalloons", displayName: "Cappadocia Balloons",    completionMessage: "The earth carved the chimneys. The sky brought the colors.",                   month: 5,  day: 3),
        Artwork(id: "winterMarket",      fileName: "winterMarket",       displayName: "Winter Market",         completionMessage: "The warmest nights are the ones spent outdoors with strangers.",               month: 5,  day: 4),
        Artwork(id: "swanGliding",        fileName: "swanGliding",        displayName: "Swan Gliding",           completionMessage: "Beneath the surface, the feet never stop moving.",                             month: 5,  day: 5),
        Artwork(id: "hotAirBalloon",     fileName: "hotAirBalloon",     displayName: "Hot Air Balloon",        completionMessage: "To rise, you only need to let go of what holds you down.",                      month: 5,  day: 6),
        Artwork(id: "driftwoodPebbles",   fileName: "driftwoodPebbles",   displayName: "Driftwood and Pebbles",  completionMessage: "The sea polishes everything it can't keep.",                                    month: 5,  day: 7),
        Artwork(id: "dragonFly",          fileName: "dragonFly",          displayName: "Dragonfly",              completionMessage: "Four wings and it still chooses to hover.",                                    month: 5,  day: 8),
        Artwork(id: "weirdBird",          fileName: "weirdBird",          displayName: "Strange Bird",           completionMessage: "The ones who don't quite fit are the ones you remember.",                     month: 5,  day: 9),
        Artwork(id: "elephantFamily",     fileName: "elephantFamily",     displayName: "Elephant Family",        completionMessage: "The youngest walks in the middle. That's how you know it's love.",             month: 5,  day: 10),
        Artwork(id: "robinStoneWall",    fileName: "robinStoneWall",    displayName: "Robin on Stone Wall",    completionMessage: "The wall tells its stories to whatever small bird will listen.",               month: 5,  day: 11),
        Artwork(id: "wildflowerMeadow",  fileName: "wildflowerMeadow",   displayName: "Wildflower Meadow",     completionMessage: "The meadow doesn't plan its colors. It just opens everything at once.",        month: 5,  day: 12),
        Artwork(id: "prairieDogTown",     fileName: "prairieDogTown",     displayName: "Prairie Dog Town",       completionMessage: "The lookout whistles and the whole town listens.",                             month: 5,  day: 13),
        Artwork(id: "magnoliaBlossoms",  fileName: "magnoliaBlossoms",  displayName: "Magnolia Blossoms",     completionMessage: "The blossoms open wide because they have nothing left to hide.",               month: 5,  day: 14),
        Artwork(id: "redBridge",          fileName: "redBridge",          displayName: "Red Bridge",             completionMessage: "The brightest color is the one that doesn't apologize.",                       month: 5,  day: 15),
        Artwork(id: "tadpolePond",       fileName: "tadpolePond",       displayName: "Tadpole Pond",           completionMessage: "Every swimmer starts by forgetting it was ever anything else.",                 month: 5,  day: 16),
        Artwork(id: "stainedGlassPeacock",fileName: "stainedGlassPeacock",displayName: "Stained Glass Peacock",  completionMessage: "The light breaks into color only when it passes through something beautiful.",  month: 5,  day: 17),
        Artwork(id: "sailboatLake",      fileName: "sailboatLake",      displayName: "Sailboat Lake",          completionMessage: "The sail catches what cannot be seen, and calls it enough.",                    month: 5,  day: 18),
        Artwork(id: "englishCottage",     fileName: "englishCottage",     displayName: "English Cottage",        completionMessage: "The ivy climbs because the wall invited it years ago.",                        month: 5,  day: 19),
        Artwork(id: "openOceanSail",       fileName: "openOceanSail",       displayName: "Open Ocean Sail",               completionMessage: "The sail catches what the hand cannot — a wind with no name and no shore.",       month: 5,  day: 20),
        Artwork(id: "apiaryGoldenHour",  fileName: "apiaryGoldenHour",  displayName: "Apiary at Golden Hour",  completionMessage: "The bees return at dusk carrying sunlight they turned into sweetness.",         month: 5,  day: 21),
        Artwork(id: "kayakLakeshore",    fileName: "kayakLakeshore",    displayName: "Kayak Lakeshore",        completionMessage: "The paddle rests because the lake already knows where to take you.",           month: 5,  day: 22),
        Artwork(id: "kingfisherDive",    fileName: "kingfisherDive",    displayName: "Kingfisher Dive",        completionMessage: "The dive lasts a heartbeat. The patience before it lasts a lifetime.",          month: 5,  day: 23),
        Artwork(id: "wheelbarrowCatNap",fileName: "wheelbarrowCatNap",displayName: "Wheelbarrow Cat Nap",    completionMessage: "The cat chose the flowers because the sun chose the wheelbarrow.",              month: 5,  day: 24),
        Artwork(id: "forestFoxMushrooms",fileName:"forestFoxMushrooms",displayName:"Forest Fox",              completionMessage: "The fox follows the light between the trees because it has nowhere else to be.", month: 5,  day: 25),
        Artwork(id: "hotAirBalloonLavender",fileName:"hotAirBalloonLavender",displayName:"Hot Air Balloons", completionMessage: "The balloons rise because the lavender already colored the ground.",            month: 5,  day: 26),
        Artwork(id: "outdoorMovieNight",fileName: "outdoorMovieNight",displayName: "Outdoor Movie Night",     completionMessage: "The screen glows and the trees lean in to watch.",                              month: 5,  day: 27),
        Artwork(id: "lighthouseWaves",   fileName: "lighthouseWaves",   displayName: "Lighthouse and Waves",   completionMessage: "The light reaches out because the dark can never reach in.",                    month: 5,  day: 28),
        Artwork(id: "thunderstormSunflowers",fileName:"thunderstormSunflowers",displayName:"Thunderstorm Sunflowers",completionMessage:"The sunflowers face forward even when the sky turns dark.",              month: 5,  day: 29),
        Artwork(id: "twilightHorizon",   fileName: "twilightHorizon",   displayName: "Twilight Horizon",       completionMessage: "The horizon holds the last light like a promise it intends to keep.",           month: 5,  day: 30),
        Artwork(id: "firefliesTwilight", fileName: "firefliesTwilight", displayName: "Fireflies at Twilight",  completionMessage: "Each tiny light is an argument that darkness hasn't won yet.",                  month: 5,  day: 31),

                // ── June — Early summer, open landscapes ────────────────────

        Artwork(id: "hummingbirdGarden", fileName: "hummingbirdGarden", displayName: "Hummingbird Garden",     completionMessage: "The smallest wings visit every bloom the garden has to offer.",                month: 6,  day: 1),
        Artwork(id: "dragonBoatRace",     fileName: "dragonBoatRace",     displayName: "Dragon Boat Race",       completionMessage: "The drums keep time so the paddles can keep faith.",                           month: 6,  day: 2),
        Artwork(id: "floatingMarket",     fileName: "floatingMarket",     displayName: "Floating Market",        completionMessage: "Commerce floats wherever people carry their generosity.",                      month: 6,  day: 3),
        Artwork(id: "monetBridge",        fileName: "monetBridge",        displayName: "Monet Bridge",           completionMessage: "The water lilies never asked to be painted. They just kept blooming.",         month: 6,  day: 4),
        Artwork(id: "castle",             fileName: "castle",             displayName: "Castle",                 completionMessage: "The strongest walls were built by someone who once felt afraid.",              month: 6,  day: 5),
        Artwork(id: "mossyWaterfall",     fileName: "mossyWaterfall",     displayName: "Mossy Waterfall",        completionMessage: "The moss grows thickest where the water never stops singing.",                  month: 6,  day: 6),
        Artwork(id: "hotAir",             fileName: "hotAir",             displayName: "Hot Air Balloon",        completionMessage: "The sky has room for everyone who's willing to let go.",                       month: 6,  day: 7),
        Artwork(id: "elephantSavanna",   fileName: "elephantSavanna",    displayName: "Elephant Savanna",       completionMessage: "The biggest footprints leave the softest echo on dry earth.",                   month: 6,  day: 8),
        Artwork(id: "heronMoonlitLake",   fileName: "heronMoonlitLake",   displayName: "Heron on Moonlit Lake",  completionMessage: "The heron waits because the moon makes the fish forget to hide.",               month: 6,  day: 9),
        Artwork(id: "goldenSailboat",     fileName: "goldenSailboat",     displayName: "Golden Sailboat",        completionMessage: "The sail doesn't choose the wind. It just agrees to go.",                     month: 6,  day: 10),
        Artwork(id: "sunflowerFarmhouse",fileName:"sunflowerFarmhouse",displayName:"Sunflower Farmhouse",    completionMessage: "Every bloom turns toward the same light without being told.",                   month: 6,  day: 11),
        Artwork(id: "treehouse",          fileName: "treehouse",          displayName: "Treehouse",              completionMessage: "Some homes are only reachable by climbing.",                                  month: 6,  day: 12),
        Artwork(id: "puffinCliff",        fileName: "puffinCliff",        displayName: "Puffin Cliff",           completionMessage: "The clumsiest flier still finds the bravest cliff to call home.",              month: 6,  day: 13),
        Artwork(id: "ferrisWheelCarnival",fileName:"ferrisWheelCarnival",displayName:"Ferris Wheel Carnival",  completionMessage: "The wheel turns slowly enough that you forget you are moving.",                 month: 6,  day: 14),
        Artwork(id: "tuscanRoad",         fileName: "tuscanRoad",         displayName: "Tuscan Road",            completionMessage: "The road lined with cypresses asks nothing but that you keep going.",          month: 6,  day: 15),
        Artwork(id: "wishingWellRoses", fileName: "wishingWellRoses", displayName: "Wishing Well Roses",     completionMessage: "The roses climb the stones because wishes need something beautiful to hold.",  month: 6,  day: 16),
        Artwork(id: "venice",             fileName: "venice",             displayName: "Venice",                 completionMessage: "The city floats because it decided sinking wasn't an option.",                 month: 6,  day: 17),
        Artwork(id: "vintageBiplane",     fileName: "vintageBiplane",     displayName: "Vintage Biplane",        completionMessage: "The oldest wings still remember what it means to leave the ground.",           month: 6,  day: 18),
        Artwork(id: "bicycleMorningGlories",fileName:"bicycleMorningGlories",displayName:"Bicycle & Morning Glories",completionMessage: "The bike leans into the flowers because it knows it's not going anywhere today.", month: 6, day: 19),
        Artwork(id: "riverKayaking",     fileName: "riverKayaking",      displayName: "River Kayaking",         completionMessage: "The canyon carved itself with the same water you're paddling through.",         month: 6,  day: 20),
        Artwork(id: "fishingPierSunset",  fileName: "fishingPierSunset",  displayName: "Fishing Pier at Sunset", completionMessage: "The pier stretches out because the horizon never comes closer.",               month: 6,  day: 21),
        Artwork(id: "trainStation",      fileName: "trainStation",       displayName: "Train Station",          completionMessage: "The clock only matters to the ones who haven't boarded yet.",                   month: 6,  day: 22),
        Artwork(id: "fishVillage",        fileName: "fishVillage",        displayName: "Fishing Village",        completionMessage: "The nets dry in the sun while the sea plans tomorrow.",                       month: 6,  day: 23),
        Artwork(id: "townChurch",         fileName: "townChurch",         displayName: "Town Church",            completionMessage: "The steeple points up so you don't have to.",                                 month: 6,  day: 24),
        Artwork(id: "tropicalSunsetCove",  fileName: "tropicalSunsetCove",  displayName: "Tropical Sunset Cove",          completionMessage: "The cove collects the sun's last colors like shells on a beach.",                 month: 6,  day: 25),
        Artwork(id: "coralLagoon",         fileName: "coralLagoon",         displayName: "Coral Lagoon",                  completionMessage: "The reef builds a city one tiny creature at a time.",                             month: 6,  day: 26),
        Artwork(id: "islandShoreline",     fileName: "islandShoreline",     displayName: "Island Shoreline",              completionMessage: "The shore belongs to whoever arrives first and stays longest.",                   month: 6,  day: 27),
        Artwork(id: "ciderPressBarn",    fileName: "ciderPressBarn",    displayName: "Cider Press Barn",       completionMessage: "The press squeezes the autumn from every apple it holds.",                      month: 6,  day: 28),
        Artwork(id: "redSquirrelPinecone",fileName:"redSquirrelPinecone",displayName:"Red Squirrel",          completionMessage: "The squirrel buries what it needs and trusts the snow to keep the secret.",     month: 6,  day: 29),
        Artwork(id: "tropicalGardenBirds", fileName: "tropicalGardenBirds", displayName: "Tropical Garden Birds",         completionMessage: "The garden sings back in a language only the birds understand.",                  month: 6,  day: 30),

                // ── July — Peak summer, tropical ────────────────────────────

        Artwork(id: "canoeLakeSunset",   fileName: "canoeLakeSunset",   displayName: "Canoe at Lake Sunset",    completionMessage: "The canoe rests on the shore because the lake already said everything.",        month: 7,  day: 1),
        Artwork(id: "tropicalFish",      fileName: "tropicalFish",      displayName: "Tropical Fish",          completionMessage: "Every color is a word in a language only the reef understands.",                month: 7,  day: 2),
        Artwork(id: "shorebirdsFlats",    fileName: "shorebirdsFlats",    displayName: "Shorebirds on the Flats",completionMessage: "The tide pulls back and the birds arrive like they were waiting.",               month: 7,  day: 3),
        Artwork(id: "heronGoldenHour",   fileName: "heronGoldenHour",   displayName: "Heron at Golden Hour",   completionMessage: "The heron turns golden when the hour does.",                                   month: 7,  day: 4),
        Artwork(id: "tidePools",          fileName: "tidePools",          displayName: "Tide Pools",             completionMessage: "The ocean leaves its brightest secrets in the smallest hollows.",              month: 7,  day: 5),
        Artwork(id: "desertOasis",        fileName: "desertOasis",        displayName: "Desert Oasis",           completionMessage: "The palms drink deep because they know the sand offers nothing twice.",        month: 7,  day: 6),
        Artwork(id: "seahorse",           fileName: "seahorse",           displayName: "Seahorse",               completionMessage: "Slowness is its own kind of current.",                                        month: 7,  day: 7),
        Artwork(id: "tallLighthouse",     fileName: "tallLighthouse",     displayName: "Lighthouse",             completionMessage: "It doesn't rescue anyone. It just refuses to go dark.",                       month: 7,  day: 8),
        Artwork(id: "volcanoIsland",     fileName: "volcanoIsland",      displayName: "Volcano Island",         completionMessage: "The island builds itself one eruption at a time.",                              month: 7,  day: 9),
        Artwork(id: "lighthouseDusk",     fileName: "lighthouseDusk",     displayName: "Lighthouse at Dusk",     completionMessage: "The light means more when the sky starts letting go.",                         month: 7,  day: 10),
        Artwork(id: "orcaBreaching",      fileName: "orcaBreaching",      displayName: "Orca Breaching",         completionMessage: "The ocean lets go of its biggest secret in one breath.",                        month: 7,  day: 11),
        Artwork(id: "jungleWaterfall",    fileName: "jungleWaterfall",    displayName: "Jungle Waterfall",       completionMessage: "The water doesn't choose the cliff. It just refuses to stop.",                month: 7,  day: 12),
        Artwork(id: "mermaidLagoon",      fileName: "mermaidLagoon",      displayName: "Mermaid Lagoon",         completionMessage: "The lagoon keeps its secrets just below the surface.",                         month: 7,  day: 13),
        Artwork(id: "tropicalWaterfall",  fileName: "tropicalWaterfall",  displayName: "Tropical Waterfall",     completionMessage: "The water falls without deciding where it will land.",                         month: 7,  day: 14),
        Artwork(id: "ospryDivingWaves",  fileName: "ospryDivingWaves",  displayName: "Osprey Diving Waves",    completionMessage: "The plunge succeeds because hesitation was never invited.",                    month: 7,  day: 15),
        Artwork(id: "coralReef",          fileName: "coralReef",          displayName: "Coral Reef",             completionMessage: "A thousand small lives build the architecture no one planned.",                month: 7,  day: 16),
        Artwork(id: "octopusTidePool",  fileName: "octopusTidePool",  displayName: "Octopus Tide Pool",      completionMessage: "Eight arms and still the starfish is just out of reach.",                       month: 7,  day: 17),
        Artwork(id: "submarinePorthole",  fileName: "submarinePorthole",  displayName: "Submarine Porthole",     completionMessage: "The glass holds back the ocean so you can see what it's hiding.",              month: 7,  day: 18),
        Artwork(id: "pinkFlamingo",       fileName: "pinkFlamingo",       displayName: "Flamingo",               completionMessage: "Standing on one leg is easy when you've forgotten the other exists.",          month: 7,  day: 19),
        Artwork(id: "hammockBeach",       fileName: "hammockBeach",       displayName: "Hammock Beach",          completionMessage: "The best view comes with no plans and two palm trees.",                        month: 7,  day: 20),
        Artwork(id: "junglePool",         fileName: "junglePool",         displayName: "Jungle Pool",            completionMessage: "The jungle hides its calmest places behind the loudest green.",                month: 7,  day: 21),
        Artwork(id: "octopusGarden",     fileName: "octopusGarden",     displayName: "Octopus Garden",         completionMessage: "Eight arms and still it holds the ocean gently.",                              month: 7,  day: 22),
        Artwork(id: "sandDunes",          fileName: "sandDunes",          displayName: "Sand Dunes",             completionMessage: "The desert remembers every wind that ever touched it.",                        month: 7,  day: 23),
        Artwork(id: "strawberry",         fileName: "strawberry",         displayName: "Strawberry Field",       completionMessage: "The sweetest things grow closest to the ground.",                              month: 7,  day: 24),
        Artwork(id: "beachHammockBooks",fileName: "beachHammockBooks",displayName: "Beach Hammock & Books",   completionMessage: "The best chapters are the ones you fall asleep in the middle of.",              month: 7,  day: 25),
        Artwork(id: "sunflowerDog",     fileName: "sunflowerDog",     displayName: "Sunflower Dog",           completionMessage: "The dog sits still because the sunflowers already did the smiling.",            month: 7,  day: 26),
        Artwork(id: "sunflowerField",    fileName: "sunflowerField",    displayName: "Sunflower Field",        completionMessage: "Every head bows the same direction when the sun decides to leave.",             month: 7,  day: 27),
        Artwork(id: "mangroveShallows",    fileName: "mangroveShallows",    displayName: "Mangrove Shallows",             completionMessage: "The roots reach into the water because the tree refused to choose between land and sea.", month: 7,  day: 28),
        Artwork(id: "wetlandHerons",       fileName: "wetlandHerons",       displayName: "Wetland Herons",                completionMessage: "The heron waits because the fish always forget about patience.",                  month: 7,  day: 29),
        Artwork(id: "tidalPoolStarfish",   fileName: "tidalPoolStarfish",   displayName: "Tidal Pool Starfish",           completionMessage: "The tide leaves its treasures for whoever bends down to look.",                   month: 7,  day: 30),
        Artwork(id: "stargazingCampfire",fileName:"stargazingCampfire",displayName:"Stargazing Campfire",    completionMessage: "The fire keeps you warm while the stars keep you wondering.",                   month: 7,  day: 31),

                // ── August — Late summer, ocean life ────────────────────────

        Artwork(id: "dolphinLeaping",     fileName: "dolphinLeaping",     displayName: "Dolphin Leaping",        completionMessage: "Joy doesn't need a reason. It just needs a surface to break.",                month: 8,  day: 1),
        Artwork(id: "blueJelly",          fileName: "blueJelly",          displayName: "Blue Jellyfish",         completionMessage: "No bones, no brain, no plan — and still it glows.",                           month: 8,  day: 2),
        Artwork(id: "lanternFestival",   fileName: "lanternFestival",    displayName: "Lantern Festival",       completionMessage: "Each light carries a wish the sky was kind enough to hold.",                    month: 8,  day: 3),
        Artwork(id: "autumnTwilight",    fileName: "autumnTwilight",    displayName: "Autumn Twilight",        completionMessage: "The sky borrows its warmth from the leaves before they let go.",                month: 8,  day: 4),
        Artwork(id: "mantaRay",           fileName: "mantaRay",           displayName: "Manta Ray",              completionMessage: "The widest wings belong to the quietest flyer.",                               month: 8,  day: 5),
        Artwork(id: "ospreyDive",         fileName: "ospreyDive",         displayName: "Osprey Dive",            completionMessage: "The best fisherman never touches the water twice.",                            month: 8,  day: 6),
        Artwork(id: "goldenCanyon",      fileName: "goldenCanyon",      displayName: "Golden Canyon",          completionMessage: "The canyon holds the sun's last gold like a secret it's been keeping all day.", month: 8,  day: 7),
        Artwork(id: "humpbackWhale",      fileName: "humpbackWhale",      displayName: "Humpback Whale",         completionMessage: "Breaking the surface is just the ocean exhaling through something enormous.",  month: 8,  day: 8),
        Artwork(id: "sunsetBlaze",       fileName: "sunsetBlaze",       displayName: "Sunset Blaze",           completionMessage: "The horizon catches fire every evening and nobody calls it an emergency.",      month: 8,  day: 9),
        Artwork(id: "slothRainforest",    fileName: "slothRainforest",    displayName: "Sloth in Rainforest",    completionMessage: "Moving slowly is not the same as standing still.",                             month: 8,  day: 10),
        Artwork(id: "seaOtter",           fileName: "seaOtter",           displayName: "Sea Otter",              completionMessage: "Floating is easy when you hold onto what matters.",                            month: 8,  day: 11),
        Artwork(id: "fountain",           fileName: "fountain",           displayName: "Market Fountain",        completionMessage: "The fountain gives the same water to pigeons and poets alike.",                 month: 8,  day: 12),
        Artwork(id: "fishingTrawler",     fileName: "fishingTrawler",     displayName: "Fishing Trawler",        completionMessage: "The nets go out empty and come back full of faith.",                           month: 8,  day: 13),
        Artwork(id: "mountainRowboat",    fileName: "mountainRowboat",    displayName: "Mountain Rowboat",       completionMessage: "A boat tied to a dock is still dreaming of the far shore.",                    month: 8,  day: 14),
        Artwork(id: "kelpForest",          fileName: "kelpForest",          displayName: "Kelp Forest",            completionMessage: "The tallest forests grow where the sun must swim to reach them.",               month: 8,  day: 15),
        Artwork(id: "pelicanColorful",    fileName: "pelicanColorful",    displayName: "Pelican",                completionMessage: "The biggest catch fits in the smallest moment of patience.",                   month: 8,  day: 16),
        Artwork(id: "moonlitHarbor",      fileName: "moonlitHarbor",      displayName: "Moonlit Harbor",         completionMessage: "The harbor glows differently when only the moon is watching.",                  month: 8,  day: 17),
        Artwork(id: "stormPetrelSea",     fileName: "stormPetrelSea",     displayName: "Storm Petrel at Sea",    completionMessage: "The smallest seabird dances on the waves the storm forgot to flatten.",          month: 8,  day: 18),
        Artwork(id: "alpineMeadow",       fileName: "alpineMeadow",       displayName: "Alpine Meadow",          completionMessage: "The wildflowers bloom without knowing anyone is watching.",                     month: 8,  day: 19),
        Artwork(id: "desertMesa",         fileName: "desertMesa",         displayName: "Desert Mesa",            completionMessage: "The mesa stands because erosion forgot to take everything.",                   month: 8,  day: 20),
        Artwork(id: "grizzlySalmon",     fileName: "grizzlySalmon",      displayName: "Grizzly Bear Fishing",  completionMessage: "The river gives to whoever stands still long enough.",                          month: 8,  day: 21),
        Artwork(id: "pingFlamingo",       fileName: "pingFlamingo",       displayName: "Flamingo Pair",          completionMessage: "Pink is just confidence wearing feathers.",                                    month: 8,  day: 22),
        Artwork(id: "pirateShip",        fileName: "pirateShip",         displayName: "Pirate Ship",            completionMessage: "The skull and crossbones fly because someone chose the horizon over the harbor.", month: 8, day: 23),
        Artwork(id: "jelly",              fileName: "jelly",              displayName: "Jellyfish",              completionMessage: "Drifting is a decision the current made for both of you.",                     month: 8,  day: 24),
        Artwork(id: "crimsonSunrise",    fileName: "crimsonSunrise",    displayName: "Crimson Sunrise",        completionMessage: "The first red light is the sky remembering it can start over.",                month: 8,  day: 25),
        Artwork(id: "marshlandDawn",     fileName: "marshlandDawn",     displayName: "Marshland at Dawn",      completionMessage: "The marsh wakes slowly because everything worth finding hides in the reeds.",  month: 8,  day: 26),
        Artwork(id: "emberGlow",          fileName: "emberGlow",          displayName: "Ember Glow",             completionMessage: "The last coals hold more heat than the first flame ever promised.",             month: 8,  day: 27),
        Artwork(id: "goldenForestLight", fileName: "goldenForestLight", displayName: "Golden Forest Light",    completionMessage: "The forest saves its best gold for the ones who walk through it slowly.",       month: 8,  day: 28),
        Artwork(id: "autumnHarvestField",  fileName: "autumnHarvestField",  displayName: "Autumn Harvest Field",          completionMessage: "The field gives everything it grew and asks only for rain next year.",            month: 8,  day: 29),
        Artwork(id: "duskMarketSquare",    fileName: "duskMarketSquare",    displayName: "Dusk Market Square",            completionMessage: "The market closes but the cobblestones remember every voice.",                    month: 8,  day: 30),
        Artwork(id: "harborMoonrise",      fileName: "harborMoonrise",      displayName: "Harbor Moonrise",               completionMessage: "The boats rock gently because the moon asked the tide to be kind tonight.",       month: 8,  day: 31),

                // ── September — Transition, birds ───────────────────────────

        Artwork(id: "japanesePagoda",     fileName: "japanesePagoda",     displayName: "Japanese Pagoda",        completionMessage: "Each tier lifts the next a little closer to the clouds.",                      month: 9,  day: 1),
        Artwork(id: "baldEagle",          fileName: "baldEagle",          displayName: "Bald Eagle",             completionMessage: "The highest branches belong to whoever refuses to look away.",                 month: 9,  day: 2),
        Artwork(id: "countyFairSunset", fileName: "countyFairSunset", displayName: "County Fair at Sunset",   completionMessage: "The ferris wheel turns because the sky is worth seeing from every angle.",      month: 9,  day: 3),
        Artwork(id: "coastalTidePools",   fileName: "coastalTidePools",   displayName: "Coastal Tide Pools",     completionMessage: "The ocean leaves small gifts in every hollow it finds.",                        month: 9,  day: 4),
        Artwork(id: "harvestMoon",       fileName: "harvestMoon",       displayName: "Harvest Moon",           completionMessage: "The moon hangs low, as if it wants to see the fields up close.",               month: 9,  day: 5),
        Artwork(id: "coastalCliffs",      fileName: "coastalCliffs",      displayName: "Coastal Cliffs",         completionMessage: "The lighthouse asks nothing of the ships. It just stays lit.",                 month: 9,  day: 6),
        Artwork(id: "eagleSouring",       fileName: "eagleSouring",       displayName: "Soaring Eagle",          completionMessage: "The wind does the lifting. The wings do the trusting.",                        month: 9,  day: 7),
        Artwork(id: "pandaBamboo",       fileName: "pandaBamboo",        displayName: "Panda in Bamboo",       completionMessage: "The bamboo grows around the panda, or maybe it's the other way.",              month: 9,  day: 8),
        Artwork(id: "moroccanSouk",       fileName: "moroccanSouk",       displayName: "Moroccan Souk",          completionMessage: "The narrowest alleys hold the richest colors.",                                month: 9,  day: 9),
        Artwork(id: "observatory",        fileName: "observatory",        displayName: "Observatory",            completionMessage: "The dome opens for anyone willing to stay up past the stars.",                 month: 9,  day: 10),
        Artwork(id: "parrot",             fileName: "parrot",             displayName: "Parrot",                 completionMessage: "The brightest voice in the forest has nothing to prove.",                      month: 9,  day: 11),
        Artwork(id: "candyShop",          fileName: "candyShop",          displayName: "Candy Shop",             completionMessage: "The sweetest things are always behind glass, waiting to be chosen.",            month: 9,  day: 12),
        Artwork(id: "tidePoolStarfish",  fileName: "tidePoolStarfish",  displayName: "Tide Pool",              completionMessage: "The pool holds the ocean's secrets in a space small enough to kneel beside.",   month: 9,  day: 13),
        Artwork(id: "twoParrots",         fileName: "twoParrots",         displayName: "Two Parrots",            completionMessage: "Conversation is just color with a heartbeat.",                                month: 9,  day: 14),
        Artwork(id: "cathedralInterior",  fileName: "cathedralInterior",  displayName: "Cathedral Interior",     completionMessage: "Light through old glass falls on everyone the same.",                          month: 9,  day: 15),
        Artwork(id: "clockworkGears",    fileName: "clockworkGears",    displayName: "Clockwork Gears",       completionMessage: "Every small turn moves something larger than itself.",                         month: 9,  day: 16),
        Artwork(id: "romanAqueduct",      fileName: "romanAqueduct",      displayName: "Roman Aqueduct",         completionMessage: "The arches carry water the way memory carries what once mattered.",            month: 9,  day: 17),
        Artwork(id: "watchTower",         fileName: "watchTower",         displayName: "Lighthouse Keeper",      completionMessage: "Someone climbs the spiral every night so the ships don't have to wonder.",     month: 9,  day: 18),
        Artwork(id: "toucanPerched",      fileName: "toucanPerched",      displayName: "Toucan",                 completionMessage: "The beak carries more color than the branch can hold.",                       month: 9,  day: 19),
        Artwork(id: "japaneseGardenKoi",fileName: "japaneseGardenKoi",displayName: "Japanese Garden",         completionMessage: "The koi circles the pond because the water never runs out of patience.",        month: 9,  day: 20),
        Artwork(id: "potteryWorkshop",    fileName: "potteryWorkshop",    displayName: "Pottery Workshop",       completionMessage: "The wheel turns and the clay remembers what your hands forgot.",               month: 9,  day: 21),
        Artwork(id: "roadrunner",         fileName: "roadrunner",         displayName: "Roadrunner",             completionMessage: "Speed only matters when you know where the dust settles.",                     month: 9,  day: 22),
        Artwork(id: "autumnStonehenge",  fileName: "autumnStonehenge",  displayName: "Autumn Stonehenge",      completionMessage: "The stones mark the turn because the sun asked them to.",                      month: 9,  day: 23),
        Artwork(id: "auroraLakeshore",     fileName: "auroraLakeshore",     displayName: "Aurora Lakeshore",              completionMessage: "The lake mirrors the sky's best trick without even trying.",                      month: 9,  day: 24),
        Artwork(id: "canyonSunsetGlow",    fileName: "canyonSunsetGlow",    displayName: "Canyon Sunset Glow",            completionMessage: "The canyon walls hold the last light like cupped hands.",                         month: 9,  day: 25),
        Artwork(id: "blazingMapleCanopy",fileName: "blazingMapleCanopy",displayName: "Blazing Maple Canopy",   completionMessage: "The maple burns from the top down, as if autumn lit a match in the crown.",     month: 9,  day: 26),
        Artwork(id: "vineyardDusk",        fileName: "vineyardDusk",        displayName: "Vineyard at Dusk",              completionMessage: "The vines hold the last warmth of the day in every cluster.",                     month: 9,  day: 27),
        Artwork(id: "ancientForestCanopy", fileName: "ancientForestCanopy", displayName: "Ancient Forest Canopy",         completionMessage: "The canopy closes above like a cathedral that never needed walls.",               month: 9,  day: 28),
        Artwork(id: "emeraldRainforest",   fileName: "emeraldRainforest",   displayName: "Emerald Rainforest",            completionMessage: "Every shade of green is a different way of saying alive.",                        month: 9,  day: 29),
        Artwork(id: "summerMarshReeds",    fileName: "summerMarshReeds",    displayName: "Summer Marsh Reeds",            completionMessage: "The reeds bend together because the wind treats them as one.",                    month: 9,  day: 30),

                // ── October — Peak autumn ───────────────────────────────────

        Artwork(id: "purpleMoose",        fileName: "purpleMoose",        displayName: "Purple Moose",           completionMessage: "Some colors exist only because someone imagined them.",                        month: 10, day: 1),
        Artwork(id: "moose",              fileName: "moose",              displayName: "Moose",                  completionMessage: "The forest makes room for anything that walks slowly enough.",                 month: 10, day: 2),
        Artwork(id: "mushroomForest",    fileName: "mushroomForest",     displayName: "Mushroom Forest",        completionMessage: "The forest floor hides its brightest colors under the oldest trees.",           month: 10, day: 3),
        Artwork(id: "ancientRuins",       fileName: "ancientRuins",       displayName: "Ancient Ruins",          completionMessage: "The jungle reclaims what was never really taken from it.",                     month: 10, day: 4),
        Artwork(id: "autumnOrchard",      fileName: "autumnOrchard",      displayName: "Autumn Orchard",         completionMessage: "The tree gives its fruit to whatever hand shows up in autumn.",                month: 10, day: 5),
        Artwork(id: "greatWallAutumn",   fileName: "greatWallAutumn",   displayName: "Great Wall Autumn",      completionMessage: "The wall stretches on, but autumn softens every edge it touches.",              month: 10, day: 6),
        Artwork(id: "mountainGoat",       fileName: "mountainGoat",       displayName: "Mountain Goat",          completionMessage: "The ledge was never as narrow as it looked from below.",                       month: 10, day: 7),
        Artwork(id: "cornfieldScarecrow",fileName:"cornfieldScarecrow",displayName:"Cornfield Scarecrow",    completionMessage: "He guards the harvest without moving — the bravest kind of standing still.",    month: 10, day: 8),
        Artwork(id: "gazelleSavanna",     fileName: "gazelleSavanna",     displayName: "Gazelle",                completionMessage: "Grace is just fear that learned how to leap.",                                 month: 10, day: 9),
        Artwork(id: "autumnBarn",        fileName: "autumnBarn",          displayName: "Autumn Barn",           completionMessage: "The barn holds the harvest like a promise it made to the field.",               month: 10, day: 10),
        Artwork(id: "redCoveredBridge",   fileName: "redCoveredBridge",   displayName: "Red Covered Bridge",     completionMessage: "The bridge wears red so you never lose your way home.",                        month: 10, day: 11),
        Artwork(id: "sleepyFox",          fileName: "sleepyFox",          displayName: "Sleepy Fox",             completionMessage: "Rest is the bravest thing a wild thing can do.",                               month: 10, day: 12),
        Artwork(id: "birchTreesAutumn",   fileName: "birchTreesAutumn",   displayName: "Birch Trees in Autumn",  completionMessage: "The white bark holds still while everything golden lets go.",                   month: 10, day: 13),
        Artwork(id: "bison",              fileName: "bison",              displayName: "Bison",                  completionMessage: "The prairie parts for what refuses to go around.",                             month: 10, day: 14),
        Artwork(id: "tigerStalking",      fileName: "tigerStalking",      displayName: "Tiger",                  completionMessage: "Stripes are just the jungle remembering where the light fell.",               month: 10, day: 15),
        Artwork(id: "coveredBridgeAutumn",fileName:"coveredBridgeAutumn",displayName:"Covered Bridge Stream",  completionMessage: "The bridge keeps its roof on so the stream can stay wild underneath.",         month: 10, day: 16),
        Artwork(id: "steamTrainViaduct", fileName: "steamTrainViaduct", displayName: "Steam Train Viaduct",    completionMessage: "The bridge holds the weight of passing things without complaint.",              month: 10, day: 17),
        Artwork(id: "bridgeAutumn",       fileName: "bridgeAutumn",       displayName: "Covered Bridge Autumn",  completionMessage: "The bridge blushes when the trees change around it.",                          month: 10, day: 18),
        Artwork(id: "autumnBench",        fileName: "autumnBench",        displayName: "Autumn Bench",           completionMessage: "The bench waits for no one, yet holds a place for everyone.",                  month: 10, day: 19),
        Artwork(id: "woodworkShop",      fileName: "woodworkShop",      displayName: "Woodwork Shop",          completionMessage: "Every tool on the wall has a story it only tells to the hands that use it.",    month: 10, day: 20),
        Artwork(id: "autumnForestPath",  fileName: "autumnForestPath",   displayName: "Autumn Forest Path",    completionMessage: "The path doesn't end. It just changes what it's covered with.",                month: 10, day: 21),
        Artwork(id: "birdFish",           fileName: "birdFish",           displayName: "Bird and Fish",          completionMessage: "They meet where the water ends and the air begins.",                          month: 10, day: 22),
        Artwork(id: "bioluminescentBay", fileName: "bioluminescentBay",  displayName: "Bioluminescent Bay",     completionMessage: "The water remembers the stars long after the sky forgets.",                     month: 10, day: 23),
        Artwork(id: "autumnParkBench",   fileName: "autumnParkBench",   displayName: "Autumn Park Bench",      completionMessage: "The leaves settle where they're welcome, and the bench never turns them away.",  month: 10, day: 24),
        Artwork(id: "autumnEveningGlow",   fileName: "autumnEveningGlow",   displayName: "Autumn Evening Glow",           completionMessage: "The evening holds the trees in amber light like a photograph it refuses to take.", month: 10,  day: 25),
        Artwork(id: "pumpkinPatchScarecrow", fileName: "pumpkinPatchScarecrow", displayName: "Pumpkin Patch",        completionMessage: "The scarecrow watches the pumpkins ripen without ever reaching for one.",       month: 10, day: 26),
        Artwork(id: "hauntedMansionDusk", fileName: "hauntedMansionDusk", displayName: "Haunted Mansion",         completionMessage: "The house has been waiting so long it forgot what it was waiting for.",          month: 10, day: 27),
        Artwork(id: "dayOfTheDeadAltar",  fileName: "dayOfTheDeadAltar",  displayName: "Day of the Dead Altar",  completionMessage: "The marigolds light a path for those who already know the way home.",            month: 10, day: 28),
        Artwork(id: "trickOrTreatNight",  fileName: "trickOrTreatNight",  displayName: "Trick or Treat Night",   completionMessage: "The costumes change every year but the magic stays the same size.",              month: 10, day: 29),
        Artwork(id: "foggyAutumnCemetery", fileName: "foggyAutumnCemetery", displayName: "Foggy Autumn Cemetery", completionMessage: "The fog softens the names on the stones until they feel like whispers.",          month: 10, day: 30),
        Artwork(id: "cranberryGrove",     fileName: "cranberryGrove",     displayName: "Cranberry Grove",        completionMessage: "The berries blush redder the longer the cold takes to arrive.",                  month: 10, day: 31),

                // ── November — Deep autumn, earth and warmth ────────────────

        Artwork(id: "gorilla",            fileName: "gorilla",            displayName: "Gorilla",                completionMessage: "Strength sits quietly until the forest needs it.",                             month: 11, day: 1),
        Artwork(id: "crystalCave",       fileName: "crystalCave",        displayName: "Crystal Cave",           completionMessage: "The earth grows its own light when no one is looking.",                         month: 11, day: 2),
        Artwork(id: "giantPanda",         fileName: "giantPanda",         displayName: "Giant Panda",            completionMessage: "The gentlest giants eat the simplest meals.",                                  month: 11, day: 3),
        Artwork(id: "rainyParis",         fileName: "rainyParis",         displayName: "Rainy Paris",            completionMessage: "The city shines brightest when the sky gives it something to reflect.",        month: 11, day: 4),
        Artwork(id: "sushiBar",           fileName: "sushiBar",           displayName: "Sushi Bar",              completionMessage: "The sharpest knife makes the gentlest cut.",                                   month: 11, day: 5),
        Artwork(id: "koala",              fileName: "koala",              displayName: "Koala",                  completionMessage: "Napping is an art when you've found the right branch.",                        month: 11, day: 6),
        Artwork(id: "streetLampReader",  fileName: "streetLampReader",  displayName: "Street Lamp Reader",     completionMessage: "The lamp asks nothing in return for keeping the page lit.",                     month: 11, day: 7),
        Artwork(id: "cobblestoneAlley",   fileName: "cobblestoneAlley",   displayName: "Cobblestone Alley",      completionMessage: "Every stone was placed by someone who never saw the cafe lights.",             month: 11, day: 8),
        Artwork(id: "bakeryInterior",    fileName: "bakeryInterior",     displayName: "French Bakery",          completionMessage: "The bread rises in the dark and fills the room with warmth by morning.",        month: 11, day: 9),
        Artwork(id: "terracedVineyard",   fileName: "terracedVineyard",   displayName: "Terraced Vineyard",      completionMessage: "The hill was too steep until someone decided to build steps for grapes.",      month: 11, day: 10),
        Artwork(id: "alpacas",            fileName: "alpacas",            displayName: "Alpacas",                completionMessage: "The softest wool comes from the most patient animals.",                        month: 11, day: 11),
        Artwork(id: "bridgeAtDusk",      fileName: "bridgeAtDusk",      displayName: "Bridge at Dusk",         completionMessage: "Dusk paints the bridge the color of almost-remembering.",                       month: 11, day: 12),
        Artwork(id: "bookshopNight",     fileName: "bookshopNight",     displayName: "Bookshop Night",         completionMessage: "The shelves hold more lives than the street outside.",                          month: 11, day: 13),
        Artwork(id: "oldCiderMill",       fileName: "oldCiderMill",       displayName: "Old Cider Mill",         completionMessage: "The wheel turns the apples into something the whole town shares.",              month: 11, day: 14),
        Artwork(id: "cactusGarden",       fileName: "cactusGarden",       displayName: "Cactus Garden",          completionMessage: "The driest soil grows the most patient beauty.",                               month: 11, day: 15),
        Artwork(id: "chameleo",           fileName: "chameleo",           displayName: "Chameleon",              completionMessage: "Changing color isn't hiding. It's listening to the room.",                     month: 11, day: 16),
        Artwork(id: "tidalHarborBoats",  fileName: "tidalHarborBoats",  displayName: "Tidal Harbor Boats",     completionMessage: "The boats rest on the mud because the sea promised to come back.",              month: 11, day: 17),
        Artwork(id: "cozyFarmhouseKitchen", fileName: "cozyFarmhouseKitchen", displayName: "Farmhouse Kitchen",  completionMessage: "The kitchen remembers every meal it ever warmed.",                              month: 11, day: 18),
        Artwork(id: "autumnMoonrise",     fileName: "autumnMoonrise",     displayName: "Autumn Moonrise",        completionMessage: "The moon rises larger in autumn, as if trying to hold more light.",             month: 11, day: 19),
        Artwork(id: "canyonCampfire",     fileName: "canyonCampfire",     displayName: "Canyon Campfire",        completionMessage: "The fire tells the canyon walls a story they echo back all night.",              month: 11, day: 20),
        Artwork(id: "paperLanternRiver",  fileName: "paperLanternRiver",  displayName: "Paper Lantern River",    completionMessage: "Each lantern carries a wish the river promises to deliver.",                    month: 11, day: 21),
        Artwork(id: "horseSleighWoodland", fileName: "horseSleighWoodland", displayName: "Horse-Drawn Sleigh",   completionMessage: "The bells jingle a song the horse has memorized by heart.",                      month: 11, day: 22),
        Artwork(id: "reindeerBirchForest", fileName: "reindeerBirchForest", displayName: "Reindeer in Birches",  completionMessage: "The reindeer moves through the white trunks like a secret the forest keeps.",   month: 11, day: 23),
        Artwork(id: "thanksgivingTable", fileName: "thanksgivingTable", displayName: "Thanksgiving Table",      completionMessage: "Every dish on the table is a story someone brought from home.",                  month: 11, day: 24),
        Artwork(id: "thanksgivingHarvestTable", fileName: "thanksgivingHarvestTable", displayName: "Harvest Table", completionMessage: "The table holds more than food — it holds the year's whole story.",           month: 11, day: 25),
        Artwork(id: "coveredBridgeSnow",  fileName: "coveredBridgeSnow",  displayName: "Covered Bridge in Snow", completionMessage: "The bridge wears its heaviest coat when the stream runs coldest.",              month: 11, day: 26),
        Artwork(id: "heronDockDawn",     fileName: "heronDockDawn",     displayName: "Heron at Dawn",           completionMessage: "The heron stands still because the dock already did the waiting.",               month: 11, day: 27),
        Artwork(id: "winterSolsticeBonfire", fileName: "winterSolsticeBonfire", displayName: "Solstice Bonfire",  completionMessage: "The longest night ends wherever a fire decides to begin.",                      month: 11, day: 28),
        Artwork(id: "dockFishingSunset", fileName: "dockFishingSunset", displayName: "Dock Fishing at Sunset",  completionMessage: "The line hangs loose because the water already knows what you need.",            month: 11, day: 29),
        Artwork(id: "holidayMarketNight", fileName: "holidayMarketNight", displayName: "Holiday Market",         completionMessage: "The stalls glow as if the cold itself were made of lantern light.",              month: 11, day: 30),

                // ── December — Winter returns, wonder ───────────────────────

        Artwork(id: "cardinalHolly",     fileName: "cardinalHolly",     displayName: "Cardinal on Holly",      completionMessage: "The red bird and the red berry share the same winter secret.",                  month: 12, day: 1),
        Artwork(id: "ferrySunset",       fileName: "ferrySunset",       displayName: "Ferry Sunset",           completionMessage: "The ferry crosses the same water twice a day and never tires of the view.",     month: 12, day: 2),
        Artwork(id: "christmasMarketNight",fileName:"christmasMarketNight",displayName:"Christmas Market Night",completionMessage: "The wooden stalls glow as if warmth itself had a shape.",                      month: 12, day: 3),
        Artwork(id: "christmasFireplace",fileName:"christmasFireplace",displayName:"Christmas Fireplace",     completionMessage: "The fire tells the same story every year, and no one tires of it.",              month: 12, day: 4),
        Artwork(id: "gingerbreadHouseSnow",fileName:"gingerbreadHouseSnow",displayName:"Gingerbread House Snow",completionMessage: "A house made of sweetness, standing bravely in the cold.",                    month: 12, day: 5),
        Artwork(id: "frozenLakeFishing", fileName: "frozenLakeFishing", displayName: "Frozen Lake Fishing",    completionMessage: "The hole in the ice is a question only patience can answer.",                   month: 12, day: 6),
        Artwork(id: "gingerbreadHouse",  fileName: "gingerbreadHouse",  displayName: "Gingerbread House",     completionMessage: "The sweetest architecture melts on the tongue, not in the rain.",              month: 12, day: 7),
        Artwork(id: "wreathWorkshop",    fileName: "wreathWorkshop",    displayName: "Wreath Workshop",        completionMessage: "The wreath is finished when you stop adding and start admiring.",               month: 12, day: 8),
        Artwork(id: "snowyVillageRooftops", fileName: "snowyVillageRooftops", displayName: "Snowy Village Rooftops", completionMessage: "The chimneys breathe smoke like the houses are dreaming of warmth.",        month: 12, day: 9),
        Artwork(id: "nutcrackerSoldier", fileName: "nutcrackerSoldier", displayName: "Nutcracker Soldier",    completionMessage: "The wooden soldier guards the mantle with a painted smile that never wavers.",  month: 12, day: 10),
        Artwork(id: "vintageToyTrain",    fileName: "vintageToyTrain",    displayName: "Vintage Toy Train",     completionMessage: "The tiny train circles a world small enough to hold in both hands.",            month: 12, day: 11),
        Artwork(id: "reindeerSleighNight",fileName:"reindeerSleighNight",displayName:"Reindeer Sleigh Night", completionMessage: "The sleigh flies because the reindeer never looked down.",                      month: 12, day: 12),
        Artwork(id: "toyWorkshop",        fileName: "toyWorkshop",        displayName: "Toy Workshop",           completionMessage: "The smallest hands build the biggest smiles.",                                 month: 12, day: 13),
        Artwork(id: "iceCastleAurora",   fileName: "iceCastleAurora",   displayName: "Ice Castle Aurora",      completionMessage: "The castle needs no torch — the sky paints its walls in green and violet.",     month: 12, day: 14),
        Artwork(id: "snowmanTwilight",   fileName: "snowmanTwilight",   displayName: "Snowman at Twilight",    completionMessage: "The twilight gives the snowman one last shadow before morning.",               month: 12, day: 15),
        Artwork(id: "carolersSnowStreet",fileName:"carolersSnowStreet",displayName:"Carolers on Snow Street",completionMessage: "The song rises from the street and the windows open one by one.",              month: 12, day: 16),
        Artwork(id: "snowyPineTwilight",  fileName: "snowyPineTwilight",  displayName: "Snowy Pine Twilight",   completionMessage: "The pines hold the snow like a gift they've been expecting.",                   month: 12, day: 17),
        Artwork(id: "christmasTreeWindow",fileName:"christmasTreeWindow",displayName:"Christmas Tree Window", completionMessage: "The tree glows brightest for the one who decorated it alone.",                  month: 12, day: 18),
        Artwork(id: "snowGlobe",          fileName: "snowGlobe",          displayName: "Snow Globe",             completionMessage: "The whole world fits inside if you shake it gently enough.",                    month: 12, day: 19),
        Artwork(id: "gingerbreadVillage",fileName:"gingerbreadVillage",displayName:"Gingerbread Village",    completionMessage: "The frosting holds the village together better than any foundation.",           month: 12, day: 20),
        Artwork(id: "northernLightsCabin", fileName: "northernLightsCabin", displayName: "Northern Lights Cabin", completionMessage: "The sky dances and the cabin watches from its porch without saying a word.",    month: 12, day: 21),
        Artwork(id: "solsticeStones",    fileName: "solsticeStones",    displayName: "Solstice Stones",        completionMessage: "The oldest stones mark the shortest day because darkness deserves a monument.", month: 12, day: 22),
        Artwork(id: "santaWorkshop",     fileName: "santaWorkshop",     displayName: "Santa's Workshop",       completionMessage: "The workshop hums with the quiet joy of making something for someone else.",    month: 12, day: 23),
        Artwork(id: "lighthouseIcyWaves",fileName:"lighthouseIcyWaves",displayName:"Lighthouse in Icy Waves", completionMessage: "The lighthouse argues with the sea every night and never loses.",               month: 12, day: 24),
        Artwork(id: "snowyChurchMidnight", fileName: "snowyChurchMidnight", displayName: "Snowy Church Midnight", completionMessage: "The steeple reaches through the snow toward a sky full of silent bells.",       month: 12, day: 25),
        Artwork(id: "boxingDayRobin",    fileName: "boxingDayRobin",    displayName: "Boxing Day Robin",       completionMessage: "The robin perches on yesterday's gift, already looking for crumbs.",            month: 12, day: 26),
        Artwork(id: "frozenGrottoFalls", fileName: "frozenGrottoFalls", displayName: "Frozen Grotto Falls",    completionMessage: "The waterfall forgot how to fall, so it learned how to gleam instead.",         month: 12, day: 27),
        Artwork(id: "deerWinterMoonlight",fileName:"deerWinterMoonlight",displayName:"Deer in Winter Moonlight",completionMessage: "The birch trees hold the moonlight so the deer can find its way.",             month: 12, day: 28),
        Artwork(id: "cozyWindowNook",    fileName: "cozyWindowNook",    displayName: "Cozy Window Nook",       completionMessage: "The best view of winter is from inside something warm.",                        month: 12, day: 29),
        Artwork(id: "stoneBridgeWinter", fileName: "stoneBridgeWinter", displayName: "Stone Bridge in Winter",  completionMessage: "The bridge holds steady because the ice beneath it never asked for help.",      month: 12, day: 30),
        Artwork(id: "newYearsRooftop",    fileName: "newYearsRooftop",    displayName: "New Year's Rooftop",    completionMessage: "The city counts down while the rooftop counts the stars.",                      month: 12, day: 31),
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
