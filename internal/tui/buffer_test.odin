package tui

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

import "core:testing"
