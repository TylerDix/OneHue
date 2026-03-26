#!/usr/bin/env python3
"""
Solve the SVG filename permutation by matching AI descriptions to filenames.
Uses keyword overlap scoring to find the best assignment.
"""

# What each mismatched file ACTUALLY shows (from AI vision)
actual_content = {
    "ancientForestCanopy": "greenhouse interior seedlings plants potting",
    "arcticOceanIce": "crab moonlit beach waves night",
    "auroraLakeshore": "eagle flying river valley mountains snow",
    "autumnEveningGlow": "hen chicks barn door sunset chickens",
    "autumnHarvestField": "apple orchard ladder tree harvest",
    "autumnMoonrise": "vineyard rows grapes purple sunset",
    "autumnTwilight": "weasel stoat stone wall autumn leaves",
    "blazingMapleCanopy": "desert tortoise canyon sunburst",
    "bookshopNight": "fox branch winter snowflakes colorful",
    "canyonCampfire": "formal dining table candles wine glasses",
    "canyonSunsetGlow": "cormorant wings dock post harbor sunset bird",
    "coralReef": "cardinal bird icy branch snowflakes winter",
    "cornfieldScarecrow": "bookshop night reader cat window books",
    "coveredBridgeSnow": "cozy cabin interior fireplace armchair books warm",
    "cranberryGrove": "great wall china mountains winding",
    "crimsonSunrise": "autumn lakeside lodge cabin reflected water twilight",
    "deepSeaAbyss": "jellyfish deep blue water glowing",
    "desertBloomSunset": "coyote fox desert sunset cacti mesa",
    "duskMarketSquare": "badger burrow autumn leaves forest",
    "emberGlow": "turkey autumn forest thanksgiving",
    "foggyCoastMorning": "sea lion rock ocean waves coastal",
    "foggyDock": "snow mountain peak climber summit alpine",
    "foxGardenArbor": "rowboat pond twilight dragonflies lily pads water",
    "goldenCanyon": "hedgehog sitting autumn forest mushrooms",
    "goldenForestLight": "pheasant walking golden wheat field sunset",
    "harborMoonrise": "sunflower field stormy sky lightning thunder",
    "harvestMoon": "cellist musician performing city skyline sunset rooftop",
    "holidayMarketNight": "horse drawn sleigh snowy woodland road winter",
    "hotAirBalloon": "sailboat reflective lake mountains sunset golden",
    "islandShoreline": "hermit crab tropical beach shells",
    "jadeMountainMist": "herons egrets cypress tree swamp wetland misty",
    "lighthouseWaves": "origami paper cranes window colorful",
    "machuPicchuLlama": "sunflower field farmhouse sunny rural",
    "mangroveShallows": "manatee swimming underwater tropical",
    "mistyMountainPines": "old fishing trawler boat beached shore nets",
    "oldCiderMill": "vintage record player phonograph cozy room",
    "openOceanSail": "pelican diving ocean waves rocky coastline",
    "owlCornfieldMoon": "fox sleeping garden arbor roses flowers",
    "parisianCafe": "person bench rain street lamp night rainy",
    "porcupine": "hedgehog mushrooms flowers forest cute",
    "rooftopCellist": "halloween porch jack-o-lanterns pumpkins spooky sunset",
    "rowboatLilyPond": "owl fence post cornfield moon night",
    "stargazerTelescope": "brown bear snowy mountain landscape winter",
    "streetLampReader": "scarecrow cornfield full moon night",
    "sunflowerFarmhouse": "hot air balloon farmland patchwork fields",
    "sunsetBlaze": "barn owl flying field orange moon night",
    "tidalPoolStarfish": "lone tree red poppies field sunset",
    "tropicalFish": "person umbrella bridge colorful city snow",
    "tropicalGardenBirds": "green tree frog leaf tropical foliage",
    "tropicalSunsetCove": "great blue heron golden marsh dragonflies",
    "veniceGondola": "bicycle parisian cafe shop cobblestone",
    "vineyardDusk": "egret heron standing water sunset reflection",
    "vintageToyTrain": "coffee cup windowsill rainy city view cozy",
    "wetlandHerons": "sea otter floating kelp forest",
    "wildflowerHillside": "hawk falcon fence post vineyard rows",
}

# Keywords that each FILENAME implies (what the image SHOULD show)
name_keywords = {
    "ancientForestCanopy": "ancient forest canopy trees old growth tall",
    "arcticOceanIce": "arctic ocean ice polar cold blue frozen",
    "auroraLakeshore": "aurora northern lights lake shore reflection",
    "autumnEveningGlow": "autumn evening glow warm sunset fall",
    "autumnHarvestField": "autumn harvest field crops pumpkins farming",
    "autumnMoonrise": "autumn moon rise night fall trees",
    "autumnTwilight": "autumn twilight dusk evening fall",
    "blazingMapleCanopy": "blazing maple canopy red orange leaves fire",
    "bookshopNight": "bookshop books night reading store window",
    "canyonCampfire": "canyon campfire fire camping night stars",
    "canyonSunsetGlow": "canyon sunset glow red rocks warm",
    "coralReef": "coral reef underwater ocean tropical fish colorful",
    "cornfieldScarecrow": "cornfield scarecrow farm crow autumn",
    "coveredBridgeSnow": "covered bridge snow winter cold wooden",
    "cranberryGrove": "cranberry grove berries red plants harvest",
    "crimsonSunrise": "crimson sunrise red dawn morning sky",
    "deepSeaAbyss": "deep sea abyss dark ocean underwater creatures",
    "desertBloomSunset": "desert bloom sunset flowers cacti sand",
    "duskMarketSquare": "dusk market square town evening vendors stalls",
    "emberGlow": "ember glow fire warm coals orange red",
    "foggyCoastMorning": "foggy coast morning fog beach ocean misty",
    "foggyDock": "foggy dock pier mist water boats",
    "foxGardenArbor": "fox garden arbor flowers roses trellis",
    "goldenCanyon": "golden canyon desert rocks warm light",
    "goldenForestLight": "golden forest light trees sunbeams autumn",
    "harborMoonrise": "harbor moon rise boats water night",
    "harvestMoon": "harvest moon large orange autumn night",
    "holidayMarketNight": "holiday market night christmas lights festive stalls",
    "hotAirBalloon": "hot air balloon sky colorful flying",
    "islandShoreline": "island shoreline beach tropical ocean palm",
    "jadeMountainMist": "jade mountain mist green asian peaks fog",
    "lighthouseWaves": "lighthouse waves ocean storm coastal beacon",
    "machuPicchuLlama": "machu picchu llama peru ruins ancient mountains",
    "mangroveShallows": "mangrove shallows swamp roots water tropical",
    "mistyMountainPines": "misty mountain pines fog trees forest alpine",
    "oldCiderMill": "old cider mill apples press barn rustic autumn",
    "openOceanSail": "open ocean sail boat sailing waves horizon",
    "owlCornfieldMoon": "owl cornfield moon night perched",
    "parisianCafe": "parisian cafe paris french tables outdoor",
    "porcupine": "porcupine quills animal forest spiky",
    "rooftopCellist": "rooftop cellist musician cello city skyline night",
    "rowboatLilyPond": "rowboat lily pond water flowers boat peaceful",
    "stargazerTelescope": "stargazer telescope night sky stars astronomy",
    "streetLampReader": "street lamp reader person reading light night book",
    "sunflowerFarmhouse": "sunflower farmhouse field rural sunny yellow",
    "sunsetBlaze": "sunset blaze sky orange red dramatic clouds",
    "tidalPoolStarfish": "tidal pool starfish ocean shore rocks marine",
    "tropicalFish": "tropical fish colorful aquarium underwater reef",
    "tropicalGardenBirds": "tropical garden birds parrots flowers lush",
    "tropicalSunsetCove": "tropical sunset cove beach palm ocean evening",
    "veniceGondola": "venice gondola canal italian boats water",
    "vineyardDusk": "vineyard dusk grapes wine rows evening",
    "vintageToyTrain": "vintage toy train model railroad miniature wooden",
    "wetlandHerons": "wetland herons birds marsh water wading",
    "wildflowerHillside": "wildflower hillside meadow colorful blooms slope",
}

def score(actual_desc, name_kw):
    """Score how well an actual description matches a name's expected keywords."""
    actual_words = set(actual_desc.lower().split())
    name_words = set(name_kw.lower().split())
    overlap = actual_words & name_words
    return len(overlap)

# Build score matrix
names = sorted(actual_content.keys())
n = len(names)
scores = {}
for file_name in names:
    desc = actual_content[file_name]
    for target_name in names:
        kw = name_keywords[target_name]
        scores[(file_name, target_name)] = score(desc, kw)

# Greedy matching: iterate, always pick the highest score
import copy
remaining_files = set(names)
remaining_targets = set(names)
mapping = {}

# Multiple passes to handle ties
while remaining_files:
    best_score = -1
    best_pair = None
    for f in remaining_files:
        for t in remaining_targets:
            s = scores[(f, t)]
            if s > best_score:
                best_score = s
                best_pair = (f, t)
    if best_pair:
        f, t = best_pair
        mapping[f] = t
        remaining_files.remove(f)
        remaining_targets.remove(t)
    else:
        break

# Output results
print("=== PERMUTATION MAPPING ===")
print("(current_filename -> should_be_named)")
print()
same = 0
diff = 0
for name in sorted(mapping):
    if mapping[name] == name:
        same += 1
    else:
        diff += 1
        desc = actual_content[name]
        print(f"  {name}")
        print(f"    shows: {desc}")
        print(f"    -> should be: {mapping[name]}")
        print()

print(f"\nSummary: {diff} need renaming, {same} stay the same")
print(f"\n=== RENAME MAP (for script) ===")
rename_map = {k: v for k, v in mapping.items() if k != v}
for k in sorted(rename_map):
    print(f"  {k}.svg -> {rename_map[k]}.svg")
