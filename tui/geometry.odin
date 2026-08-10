package tui

Rect :: struct {
	x, y:          int,
	width, height: int,
}

rect_contains :: proc(rect: Rect, x, y: int) -> bool {
	return x >= rect.x && y >= rect.y && x < rect.x+rect.width && y < rect.y+rect.height
}
