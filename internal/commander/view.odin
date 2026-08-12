package commander

import "core:fmt"
import "tc:internal/tui"

draw :: proc(ctx: ^tui.Context, app: ^App_State) {
	buffer := tui.begin_frame(ctx)
	width, height := tui.size(ctx)
	theme := theme_for(app.theme_mode)
	tui.buffer_fill(
		buffer,
		tui.Rect{x = 0, y = 0, width = width, height = height},
		tui.Cell{character = ' ', style = theme.screen},
	)
	if width < 20 || height < 8 {
		tui.buffer_write(buffer, 0, 0, "Terminal jest zbyt mały", theme.dialog_accent)
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
		theme,
	)
	draw_panel(
		buffer,
		tui.Rect{x = left_width, y = 0, width = width - left_width, height = panel_height},
		&app.panels[1],
		app.active_panel == 1,
		theme,
	)

	tui.buffer_fill(
		buffer,
		tui.Rect{x = 0, y = height - 2, width = width, height = 1},
		tui.Cell{character = ' ', style = theme.status},
	)
	if app.copying {
		status_buffer: [512]byte
		status := fmt.bprintf(
			status_buffer[:],
			"Kopiowanie %s: %d%%",
			app.copy_name,
			app.copy_percent,
		)
		tui.buffer_write(buffer, 1, height - 2, status, theme.status, width - 2)
	} else {
		tui.buffer_write(buffer, 1, height - 2, app.status, theme.status, width - 2)
	}

	tui.buffer_fill(
		buffer,
		tui.Rect{x = 0, y = height - 1, width = width, height = 1},
		tui.Cell{character = ' ', style = theme.keys},
	)
	tui.buffer_write(
		buffer,
		0,
		height - 1,
		"Tab Panel  Enter Otwórz  ↑/↓ Wybór  F5 Kopiuj  Esc Koniec",
		theme.keys,
		width,
	)

	if app.overwrite_pending {
		draw_overwrite_dialog(buffer, width, height, app.copy_name, theme)
	} else if app.copying {
		draw_copy_progress_dialog(buffer, width, height, app.copy_name, app.copy_percent, theme)
	}
}

draw_overwrite_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	file_name: string,
	theme: Theme,
) {
	dialog := dialog_open(buffer, width, height, 7, "Potwierdzenie", theme)
	dialog_write(dialog, 2, "Plik docelowy już istnieje:")
	dialog_write(dialog, 3, file_name, .Accent)
	dialog_write(dialog, 5, " Enter/T Nadpisz    Esc/N Anuluj ", .Action)
}

draw_copy_progress_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	file_name: string,
	percent: int,
	theme: Theme,
) {
	dialog := dialog_open(buffer, width, height, 7, "Kopiowanie", theme)
	dialog_write(dialog, 2, file_name)
	dialog_progress(dialog, 4, percent)
	percent_text: [16]byte
	text := fmt.bprintf(percent_text[:], "%d%%", percent)
	text_x := dialog.rect.x + (dialog.rect.width - len(text)) / 2
	tui.buffer_write(buffer, text_x, dialog.rect.y + 5, text, theme.dialog_accent)
}

draw_panel :: proc(
	buffer: ^tui.Buffer,
	rect: tui.Rect,
	state: ^Panel_State,
	active: bool,
	theme: Theme,
) {
	border_style := theme.panel_border_inactive
	if active {
		border_style = theme.panel_border_active
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
		row_style := theme.panel_row_inactive
		if active {
			row_style = theme.panel_row_active
		}
		if active && index == state.selected {
			row_style = theme.selection_active
		} else if index == state.selected {
			row_style = theme.selection_inactive
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
