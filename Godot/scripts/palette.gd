class_name TrainPalette
extends RefCounted

const COLORS = [Color("bd493d"), Color("287fb2"), Color("e0ad38"), Color("278669"), Color("8461aa")]
const NAMES = ["Kırmızı", "Mavi", "Sarı", "Yeşil", "Mor"]
const SYMBOLS = ["●", "■", "◆", "+", "▲"]
const INK = Color("edf2ef")
const MUTED = Color("b0c1c5")
const PAPER = Color("19313b")
const MINT = Color("dcebdc")
const DARK = Color("367b80")

static func color(index: int) -> Color:
	return COLORS[clampi(index, 0, 4)]

