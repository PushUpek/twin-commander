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

RGB_Color :: struct {
	r:     u8,
	g:     u8,
	b:     u8,
	valid: bool,
}

Attributes :: bit_set[Attribute]

Attribute :: enum {
	Bold,
	Dim,
	Underline,
	Reverse,
}

Style :: struct {
	foreground:     Color,
	background:     Color,
	foreground_rgb: RGB_Color,
	background_rgb: RGB_Color,
	attributes:     Attributes,
}

rgb :: proc(value: u32) -> RGB_Color {
	return RGB_Color {
		r     = u8((value >> 16) & 0xff),
		g     = u8((value >> 8) & 0xff),
		b     = u8(value & 0xff),
		valid = true,
	}
}

rgb_style :: proc(foreground, background: u32, attributes := Attributes{}) -> Style {
	return Style {
		foreground_rgb = rgb(foreground),
		background_rgb = rgb(background),
		attributes = attributes,
	}
}

rgb_background_style :: proc(background: u32) -> Style {
	return Style{background_rgb = rgb(background)}
}

Cell :: struct {
	character: rune,
	style:     Style,
}

DEFAULT_CELL :: Cell {
	character = ' ',
}
