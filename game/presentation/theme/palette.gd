class_name Palette
extends RefCounted
## Single source of truth for every colour in the game. Bright, high-contrast toy colours
## chosen so the five wagon colours stay distinguishable for common colour-vision
## deficiencies (each also differs clearly in lightness), and backgrounds stay calmer
## than the pieces the player must read.

## Wagon/collector colours, indexed by the colour id used in campaign data. Rich
## railway-livery tones rather than neon: they stay clearly distinct (each also differs
## in lightness for colour-vision deficiencies) without looking like plastic toys.
const WAGONS: Array[Color] = [
	Color("d93a34"), # 0 red
	Color("2c7be5"), # 1 blue
	Color("f2b705"), # 2 yellow
	Color("2fa35a"), # 3 green
	Color("8a4fd1"), # 4 purple
]

const INK := Color("1d2b4f")
const INK_SOFT := Color("50618c")
const WHITE := Color("ffffff")
const CREAM := Color("fff8e8")
const GOLD := Color("ffc531")
const GOLD_DARK := Color("e08a00")
const DANGER := Color("ff4b55")
const SUCCESS := Color("1fcf7a")
const SKY_TOP := Color("7fd3ff")
const SKY_BOTTOM := Color("c9f0ff")

const BUTTON_PRIMARY := Color("ffb321")
const BUTTON_PRIMARY_EDGE := Color("d97a00")
const BUTTON_BLUE := Color("3f8cff")
const BUTTON_BLUE_EDGE := Color("2257c7")
const BUTTON_GREEN := Color("2ed47f")
const BUTTON_GREEN_EDGE := Color("159652")
const PANEL := Color("ffffff")
const PANEL_EDGE := Color("c8d6f0")


## Train parts shared by every wagon and the locomotive.
const CHASSIS := Color("2a2f38")
const STEEL := Color("a7b0ba")
const WHEEL := Color("3b4048")
const GLASS := Color("23394a")
const LAMP := Color("fff1b8")
const ENGINE_BODY := Color("1f3f8f")
const ENGINE_STRIPE := Color("f4c430")

## Railway infrastructure.
const RAIL := Color("b9c2cc")
const SLEEPER := Color("5c4030")
const CURB := Color("b9b3a6")
const PLATFORM := Color("b8b1a2")
const PLATFORM_EDGE := Color("f2c230")
const STATION_WALL := Color("e9dcc3")
const STATION_ROOF := Color("8c3b2f")
const STATION_TRIM := Color("4a3a30")
const CANOPY := Color("56606b")

## Per-theme environment: grass base, ballast/yard gravel, sky (clear) colour, foliage.
const THEMES: Array[Dictionary] = [
	{"ground": Color("6aa84f"), "gravel": Color("6e6a64"), "clear": Color("6aa84f"), "foliage": Color("3d7a3a")},  # meadow
	{"ground": Color("d9c38f"), "gravel": Color("7a746b"), "clear": Color("d9c38f"), "foliage": Color("4c8a45")},  # coast
	{"ground": Color("88b04b"), "gravel": Color("6e6a64"), "clear": Color("88b04b"), "foliage": Color("4a8238")},  # farmland
	{"ground": Color("7f9f6a"), "gravel": Color("67645f"), "clear": Color("7f9f6a"), "foliage": Color("3f6e45")},  # old station
	{"ground": Color("c98a55"), "gravel": Color("7d6a5a"), "clear": Color("c98a55"), "foliage": Color("6f7d45")},  # canyon
	{"ground": Color("f6f9fc"), "gravel": Color("6c717a"), "clear": Color("f6f9fc"), "foliage": Color("2f5e4a")},  # snow
]


static func wagon(color_id: int) -> Color:
	return WAGONS[clampi(color_id, 0, WAGONS.size() - 1)]


static func theme(theme_id: int) -> Dictionary:
	return THEMES[clampi(theme_id, 0, THEMES.size() - 1)]
