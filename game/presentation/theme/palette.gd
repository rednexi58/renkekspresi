class_name Palette
extends RefCounted
## Single source of truth for every colour in the game. Bright, high-contrast toy colours
## chosen so the five wagon colours stay distinguishable for common colour-vision
## deficiencies (each also differs clearly in lightness), and backgrounds stay calmer
## than the pieces the player must read.

## Wagon/collector colours, indexed by the colour id used in campaign data.
const WAGONS: Array[Color] = [
	Color("ff4b55"), # 0 red
	Color("2f8bff"), # 1 blue
	Color("ffc31f"), # 2 yellow
	Color("1fcf7a"), # 3 green
	Color("a45bff"), # 4 purple
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

## Puzzle board: the same calm blue on every theme so pieces always read the same way.
const BOARD := Color("4a6fd1")
const BOARD_EDGE := Color("3352a8")
const BOARD_CELL := Color("eaf1ff")
const PLATFORM := Color("ffe2a8")
const PLATFORM_EDGE := Color("d9a75a")
const BERTH_EMPTY := Color("ffffff")

## Train parts shared by every wagon and the locomotive.
const CHASSIS := Color("2b3550")
const STEEL := Color("aab8cc")
const BRASS := Color("ffcf5c")
const GLASS := Color("9fe9ff")
const LAMP := Color("fff3b0")
const TRAIN_CREAM := Color("fff4dc")
const ENGINE_BODY := Color("ff5a4e")
const ENGINE_ACCENT := Color("ffd23f")

## Per-theme environment: ground, ground accent, track bed, sky/clear colour.
const THEMES: Array[Dictionary] = [
	{"ground": Color("62c454"), "accent": Color("52b046"), "bed": Color("8f7f6c"), "clear": Color("7fd6ff")},  # meadow
	{"ground": Color("efd38e"), "accent": Color("e3c070"), "bed": Color("9c8670"), "clear": Color("6fd3ff")},  # coast
	{"ground": Color("86c94e"), "accent": Color("74b740"), "bed": Color("8f7f6c"), "clear": Color("8edcff")},  # farmland
	{"ground": Color("8dbf78"), "accent": Color("7aad66"), "bed": Color("857a70"), "clear": Color("9ad8ff")},  # old station
	{"ground": Color("e8955a"), "accent": Color("d98047"), "bed": Color("9a7860"), "clear": Color("ffc89a")},  # canyon
	{"ground": Color("d6e6f7"), "accent": Color("c2d6ee"), "bed": Color("7d8799"), "clear": Color("a9d8ff")},  # snow
]


static func wagon(color_id: int) -> Color:
	return WAGONS[clampi(color_id, 0, WAGONS.size() - 1)]


static func theme(theme_id: int) -> Dictionary:
	return THEMES[clampi(theme_id, 0, THEMES.size() - 1)]
