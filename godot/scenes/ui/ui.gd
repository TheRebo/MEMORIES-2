class_name UI
extends RefCounted
## Palette shared by scripts (the look itself lives in resources/theme/main_theme.tres).
## Wood for the game's own chrome, cream paper with dark ink for what MC writes.

const CREAM := Color("f4e6c8")
const CREAM_DIM := Color("d3bf9b")
const AMBER := Color("f2b84b")
const AMBER_DEEP := Color("c98a2b")
const AMBER_ON_WOOD := Color("ffe08f")
const INK := Color("120b07")
const WOOD_900 := Color("170f0a")
const WOOD_800 := Color("241811")
const WOOD_700 := Color("33231a")
const WOOD_600 := Color("4a3324")
const WOOD_500 := Color("6b4a33")
const PAPER := Color("efe2c3")
const PAPER_SHADE := Color("ddc9a0")
const PAPER_EDGE := Color("b89c6c")
const PAPER_INK := Color("2a1b11")
const PAPER_INK_SOFT := Color("6a5038")
const PAPER_DONE := Color("3d6a31")
const PAPER_RED := Color("9a3622")
const SAGE := Color("a9d18e")
const WARN := Color("f08a72")


## Label styled by a theme variation (used for rows built from data).
static func label(text: String, variation: String = "", size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l
