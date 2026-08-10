package tui

Color :: enum u8 {
	Default,
	Black,
	Red,
	Green,
	Yellow,
	Blue,
	Magenta,
	Cyan,
	White,
}

Attributes :: bit_set[Attribute]

Attribute :: enum {
	Bold,
	Dim,
	Underline,
	Reverse,
}

Style :: struct {
	foreground: Color,
	background: Color,
	attributes: Attributes,
}

Cell :: struct {
	character: rune,
	style:     Style,
}

DEFAULT_CELL :: Cell{character = ' '}
