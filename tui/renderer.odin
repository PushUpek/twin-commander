package tui

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"

Screen :: struct {
	front:        Buffer,
	back:         Buffer,
	force_redraw: bool,
}

screen_init :: proc(screen: ^Screen, width, height: int) {
	screen_destroy(screen)
	buffer_init(&screen.front, width, height)
	buffer_init(&screen.back, width, height)
	screen.force_redraw = true
}

screen_destroy :: proc(screen: ^Screen) {
	if screen == nil {
		return
	}
	buffer_destroy(&screen.front)
	buffer_destroy(&screen.back)
	screen^ = {}
}

screen_resize :: proc(screen: ^Screen, width, height: int) {
	if screen.back.width == width && screen.back.height == height {
		return
	}
	screen_init(screen, width, height)
}

screen_begin :: proc(screen: ^Screen) -> ^Buffer {
	buffer_clear(&screen.back)
	return &screen.back
}

screen_render :: proc(screen: ^Screen) -> strings.Builder {
	output := strings.builder_make()
	active_style := Style{}
	style_valid := false

	for y in 0..<screen.back.height {
		x := 0
		for x < screen.back.width {
			index := y*screen.back.width+x
			cell := screen.back.cells[index]
			if !screen.force_redraw && cell == screen.front.cells[index] {
				x += 1
				continue
			}

			fmt.sbprintf(&output, "\e[%d;%dH", y+1, x+1)
			for x < screen.back.width {
				index = y*screen.back.width+x
				cell = screen.back.cells[index]
				if !screen.force_redraw && cell == screen.front.cells[index] {
					break
				}
				if !style_valid || cell.style != active_style {
					write_style(&output, cell.style)
					active_style = cell.style
					style_valid = true
				}
				if cell.character != 0 {
					encoded, count := utf8.encode_rune(cell.character)
					strings.write_bytes(&output, encoded[:count])
				}
				x += 1
			}
		}
	}

	strings.write_string(&output, "\e[0m")
	buffer_copy(&screen.front, &screen.back)
	screen.force_redraw = false
	return output
}

write_style :: proc(output: ^strings.Builder, style: Style) {
	strings.write_string(output, "\e[0")
	if .Bold in style.attributes do strings.write_string(output, ";1")
	if .Dim in style.attributes do strings.write_string(output, ";2")
	if .Underline in style.attributes do strings.write_string(output, ";4")
	if .Reverse in style.attributes do strings.write_string(output, ";7")
	if style.foreground != .Default do fmt.sbprintf(output, ";%d", 29+int(style.foreground))
	if style.background != .Default do fmt.sbprintf(output, ";%d", 39+int(style.background))
	strings.write_string(output, "m")
}
