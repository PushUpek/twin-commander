package tui

import "core:strings"

@(test)
buffer_clips_text :: proc(t: ^testing.T) {
	buffer: Buffer
	buffer_init(&buffer, 4, 2)
	defer buffer_destroy(&buffer)

	buffer_write(&buffer, 2, 0, "abcd")
	testing.expect_value(t, buffer_get(&buffer, 2, 0).character, rune('a'))
	testing.expect_value(t, buffer_get(&buffer, 3, 0).character, rune('b'))
}

@(test)
buffer_clips_rectangles :: proc(t: ^testing.T) {
	buffer: Buffer
	buffer_init(&buffer, 3, 3)
	defer buffer_destroy(&buffer)

	buffer_fill(&buffer, Rect{x = -1, y = -1, width = 3, height = 3}, Cell{character = '#'})
	testing.expect_value(t, buffer_get(&buffer, 0, 0).character, rune('#'))
	testing.expect_value(t, buffer_get(&buffer, 1, 1).character, rune('#'))
	testing.expect_value(t, buffer_get(&buffer, 2, 2).character, rune(' '))
}

@(test)
renderer_repositions_after_unicode_and_escapes_control :: proc(t: ^testing.T) {
	screen: Screen
	screen_init(&screen, 8, 1)
	defer screen_destroy(&screen)
	buffer_write(&screen.back, 0, 0, "¶name¶")
	buffer_set(&screen.back, 6, 0, Cell{character = '\x1b'})
	output := screen_render(&screen)
	defer strings.builder_destroy(&output)
	rendered := strings.to_string(output)
	testing.expect(t, strings.has_prefix(rendered, "\e[2J\e[H"))
	testing.expect(t, strings.contains(rendered, "\e[1;2Hname"))
	testing.expect(t, strings.contains(rendered, "\e[1;7H?"))
	testing.expect(t, !strings.contains(rendered, "\e[1;7H\e"))
}

@(test)
renderer_repositions_after_double_width_unicode :: proc(t: ^testing.T) {
	screen: Screen
	screen_init(&screen, 8, 1)
	defer screen_destroy(&screen)
	buffer_write(&screen.back, 0, 0, "界name")
	output := screen_render(&screen)
	defer strings.builder_destroy(&output)
	testing.expect(t, strings.contains(strings.to_string(output), "\e[1;3Hname"))
}

import "core:testing"

@(test)
rgb_color_preserves_all_channels :: proc(t: ^testing.T) {
	color := rgb(0x4d699b)
	testing.expect(t, color.valid)
	testing.expect_value(t, color.r, u8(0x4d))
	testing.expect_value(t, color.g, u8(0x69))
	testing.expect_value(t, color.b, u8(0x9b))
}
