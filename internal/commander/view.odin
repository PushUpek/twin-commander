package commander

import "core:fmt"
import "tc:internal/tui"

draw :: proc(ctx: ^tui.Context, app: ^App_State) {
	buffer := tui.begin_frame(ctx)
	width, height := tui.size(ctx)
	if width < 20 || height < 8 {
		tui.buffer_write(buffer, 0, 0, "Terminal jest zbyt mały", tui.Style{foreground = .Yellow})
		return
	}

	footer_height := 2
	left_width := width / 2
	panel_height := height - footer_height
	draw_panel(
		buffer,
		tui.Rect{x = 0, y = 0, width = left_width, height = panel_height},
		&app.panels[0],
		app.active_panel == 0,
	)
	draw_panel(
		buffer,
		tui.Rect{x = left_width, y = 0, width = width - left_width, height = panel_height},
		&app.panels[1],
		app.active_panel == 1,
	)

	status_style := tui.Style {
		foreground = .Black,
		background = .Cyan,
	}
	tui.buffer_fill(
		buffer,
		tui.Rect{x = 0, y = height - 2, width = width, height = 1},
		tui.Cell{character = ' ', style = status_style},
	)
	if app.copying {
		status_buffer: [512]byte
		status := fmt.bprintf(
			status_buffer[:],
			"Kopiowanie %s: %d%%",
			app.copy_name,
			app.copy_percent,
		)
		tui.buffer_write(buffer, 1, height - 2, status, status_style, width - 2)
	} else {
		tui.buffer_write(buffer, 1, height - 2, app.status, status_style, width - 2)
	}

	keys_style := tui.Style {
		foreground = .Black,
		background = .White,
	}
	tui.buffer_fill(
		buffer,
		tui.Rect{x = 0, y = height - 1, width = width, height = 1},
		tui.Cell{character = ' ', style = keys_style},
	)
	tui.buffer_write(
		buffer,
		0,
		height - 1,
		"Tab Panel  Enter Otwórz  ↑/↓ Wybór  F5 Kopiuj  Esc Koniec",
		keys_style,
		width,
	)
}

draw_panel :: proc(buffer: ^tui.Buffer, rect: tui.Rect, state: ^Panel_State, active: bool) {
	border_style := tui.Style {
		foreground = .White,
		attributes = {.Dim},
	}
	if active {
		border_style = tui.Style {
			foreground = .White,
			attributes = {.Bold},
		}
	}
	draw_box(buffer, rect, border_style)
	tui.buffer_set(buffer, rect.x + 1, rect.y, tui.Cell{character = ' ', style = border_style})
	title_width := tui.buffer_write(
		buffer,
		rect.x + 2,
		rect.y,
		state.path,
		border_style,
		rect.width - 4,
	)
	if rect.x + 2 + title_width < rect.x + rect.width - 1 {
		tui.buffer_set(
			buffer,
			rect.x + 2 + title_width,
			rect.y,
			tui.Cell{character = ' ', style = border_style},
		)
	}

	visible_rows := max(rect.height - 2, 0)
	if state.selected < state.offset {
		state.offset = state.selected
	} else if visible_rows > 0 && state.selected >= state.offset + visible_rows {
		state.offset = state.selected - visible_rows + 1
	}

	item_count := panel_item_count(state)
	for row in 0 ..< min(visible_rows, item_count - state.offset) {
		index := state.offset + row
		row_style := tui.Style {
			foreground = .White,
			attributes = {.Dim},
		}
		if active {
			row_style = {}
		}
		if active && index == state.selected {
			row_style = tui.Style {
				foreground = .Black,
				background = .Cyan,
			}
		} else if index == state.selected {
			row_style.attributes += {.Underline}
		}
		tui.buffer_fill(
			buffer,
			tui.Rect{x = rect.x + 1, y = rect.y + 1 + row, width = rect.width - 2, height = 1},
			tui.Cell{character = ' ', style = row_style},
		)

		name := ".."
		name_buffer: [1024]byte
		if index > 0 {
			file := state.files[index - 1]
			if file.type == .Directory {
				name = fmt.bprintf(name_buffer[:], "[%s]", file.name)
			} else {
				name = file.name
			}
		}
		tui.buffer_write(buffer, rect.x + 2, rect.y + 1 + row, name, row_style, rect.width - 4)
	}
}

draw_box :: proc(buffer: ^tui.Buffer, rect: tui.Rect, style: tui.Style) {
	if rect.width < 2 || rect.height < 2 {
		return
	}
	left, right := rect.x, rect.x + rect.width - 1
	top, bottom := rect.y, rect.y + rect.height - 1
	tui.buffer_set(buffer, left, top, tui.Cell{character = '┌', style = style})
	tui.buffer_set(buffer, right, top, tui.Cell{character = '┐', style = style})
	tui.buffer_set(buffer, left, bottom, tui.Cell{character = '└', style = style})
	tui.buffer_set(buffer, right, bottom, tui.Cell{character = '┘', style = style})
	for x in left + 1 ..< right {
		tui.buffer_set(buffer, x, top, tui.Cell{character = '─', style = style})
		tui.buffer_set(buffer, x, bottom, tui.Cell{character = '─', style = style})
	}
	for y in top + 1 ..< bottom {
		tui.buffer_set(buffer, left, y, tui.Cell{character = '│', style = style})
		tui.buffer_set(buffer, right, y, tui.Cell{character = '│', style = style})
	}
}
