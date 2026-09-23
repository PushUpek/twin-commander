package tui

import "core:unicode"

Buffer :: struct {
	width, height: int,
	cells:         []Cell,
}

buffer_init :: proc(buffer: ^Buffer, width, height: int) {
	buffer_destroy(buffer)
	buffer.width = max(width, 0)
	buffer.height = max(height, 0)
	buffer.cells = make([]Cell, buffer.width * buffer.height)
	buffer_clear(buffer)
}

buffer_destroy :: proc(buffer: ^Buffer) {
	if buffer == nil {
		return
	}
	delete(buffer.cells)
	buffer^ = {}
}

buffer_clear :: proc(buffer: ^Buffer, cell := DEFAULT_CELL) {
	for &current in buffer.cells {
		current = cell
	}
}

buffer_set :: proc(buffer: ^Buffer, x, y: int, cell: Cell) {
	if buffer == nil || x < 0 || y < 0 || x >= buffer.width || y >= buffer.height {
		return
	}
	buffer.cells[y * buffer.width + x] = cell
}

buffer_get :: proc(buffer: ^Buffer, x, y: int) -> Cell {
	if buffer == nil || x < 0 || y < 0 || x >= buffer.width || y >= buffer.height {
		return DEFAULT_CELL
	}
	return buffer.cells[y * buffer.width + x]
}

buffer_fill :: proc(buffer: ^Buffer, rect: Rect, cell: Cell) {
	left := max(rect.x, 0)
	top := max(rect.y, 0)
	right := min(rect.x + rect.width, buffer.width)
	bottom := min(rect.y + rect.height, buffer.height)
	for y in top ..< bottom {
		for x in left ..< right {
			buffer_set(buffer, x, y, cell)
		}
	}
}

buffer_write :: proc(
	buffer: ^Buffer,
	x, y: int,
	text: string,
	style := Style{},
	max_width := -1,
) -> int {
	cursor := x
	limit := buffer.width
	if max_width >= 0 {
		limit = min(limit, x + max_width)
	}

	for character in text {
		width := unicode.normalized_east_asian_width(character)
		if width <= 0 {
			continue
		}
		if cursor + width > limit {
			break
		}
		buffer_set(buffer, cursor, y, Cell{character = character, style = style})
		if width == 2 {
			buffer_set(buffer, cursor + 1, y, Cell{character = 0, style = style})
		}
		cursor += width
	}
	return cursor - x
}

buffer_copy :: proc(destination, source: ^Buffer) {
	assert(destination.width == source.width && destination.height == source.height)
	copy(destination.cells, source.cells)
}
