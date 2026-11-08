class_name Palette
extends RefCounted
## Single source of truth for every colour in the game. The look follows the bright,
## warm, tactile style of top casual puzzlers: saturated piece colours on calm cream and
## soft green, so the pieces are always the most vivid thing on screen. The five piece
## colours also differ clearly in lightness for colour-vision deficiencies.

## Wagon/collector colours, indexed by the colour id used in campaign data.
const WAGONS: Array[Color] = [
	Color("f23d3d"), # 0 red
	Color("2f6dff"), # 1 blue
	Color("ffc414"), # 2 yellow
	Color("22c55e"), # 3 green
	Color("9b4dff"), # 4 purple
]

const INK := Color("3b2a1e")
const INK_SOFT := Color("7a5f45")
const WHITE := Color("ffffff")
const CREAM := Color("fff6e4")
const GOLD := Color("ffc53d")
const GOLD_DARK := Color("d88a10")
const GOLD_LIGHT := Color("ffe9a8")
const DANGER := Color("ff4b4b")
const SUCCESS := Color("2ecc71")

## Interface.
const BUTTON_PRIMARY := Color("ffb21e")
const BUTTON_PRIMARY_EDGE := Color("d97a00")
const BUTTON_BLUE := Color("3f8cff")
const BUTTON_BLUE_EDGE := Color("2257c7")
const BUTTON_GREEN := Color("39d07a")
const BUTTON_GREEN_EDGE := Color("1a9a52")
const PANEL := Color("fff8ea")
const PANEL_EDGE := Color("e2c48f")

## Board, shelf and scene ground.
const BOARD := Color("f8ecd2")
const BOARD_SHADE := Color("efdcb8")
const SHELF := Color("e9c993")
const SHELF_BAND := Color("f1dcb2")
const SHELF_EDGE := Color("c99b5c")
const SHELF_SLOT := Color("d6b07a")
## Scene ground per level theme (meadow, coast, farmland, old station, canyon, snow):
## light, low-contrast tints so the train always stands out.
const SCENE_GROUNDS: Array[Color] = [
	Color("c3e597"), Color("f4dfb2"), Color("d7ea9c"), Color("cfe5b6"), Color("f6d2a6"), Color("e8f2fb"),
]
const PATH := Color("efd2a4")
const PATH_STITCH := Color("c99f6e")

## Rolling stock parts shared by every wagon and the locomotive.
const CHASSIS := Color("3a3f4b")
const WHEEL := Color("2e323b")
const HUB := Color("d9dee6")
const BRASS := Color("f5c542")
const ENGINE_BODY := Color("2c3e78")
const ENGINE_CAB := Color("e8473c")
const LAMP := Color("fff3b8")

## Railway details in the scene.
const RAIL := Color("8a6a4f")
const SLEEPER := Color("a57a55")
const BUFFER := Color("e8473c")

## Small decorations scattered on the grass.
const FLOWER_PETALS: Array[Color] = [Color("ffffff"), Color("ff8fb8"), Color("ffd84d"), Color("b08cff")]
const FLOWER_CENTRE := Color("ffb02e")
const BUSH := Color("7cc84f")
const ROCK := Color("d8cbb8")


static func scene_ground(theme_id: int) -> Color:
	return SCENE_GROUNDS[clampi(theme_id, 0, SCENE_GROUNDS.size() - 1)]


static func wagon(color_id: int) -> Color:
	return WAGONS[clampi(color_id, 0, WAGONS.size() - 1)]
