package commander

import "core:fmt"
import "core:os"
import "tc:internal/tui"

PANEL_SIZE_WIDTH :: 7
PANEL_PERMISSIONS_WIDTH :: 11
PANEL_COLUMN_GAP :: 1
PANEL_MIN_NAME_WIDTH :: 5

draw :: proc(ctx: ^tui.Context, app: ^App_State) {
	buffer := tui.begin_frame(ctx)
	width, height := tui.size(ctx)
	theme := app.theme
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
	theme_label := theme.name
	theme_label_x := max(width - len(theme_label) - 1, 1)
	tui.buffer_write(
		buffer,
		theme_label_x,
		height - 2,
		theme_label,
		theme.status,
		width - theme_label_x,
	)

	tui.buffer_fill(
		buffer,
		tui.Rect{x = 0, y = height - 1, width = width, height = 1},
		tui.Cell{character = ' ', style = theme.keys},
	)
	tui.buffer_write(
		buffer,
		0,
		height - 1,
		"F3 Podgląd  F4 Edycja  F5 Kopiuj  F6 Przenieś  F8 Usuń  Tab Panel  Esc Koniec",
		theme.keys,
		width,
	)

	if app.overwrite_pending {
		if app.pending_count > 1 {
			draw_bulk_confirmation_dialog(buffer, width, height, app.copy_name, app.pending_count, .Copy, theme)
		} else {
			draw_overwrite_dialog(buffer, width, height, app.copy_name, theme)
		}
	} else if app.move_pending {
		if app.pending_count > 1 {
			draw_bulk_confirmation_dialog(buffer, width, height, app.pending_name, app.pending_count, .Move, theme)
		} else {
			draw_move_overwrite_dialog(buffer, width, height, app.pending_name, theme)
		}
	} else if app.delete_pending {
		if app.pending_count > 1 {
			draw_bulk_confirmation_dialog(buffer, width, height, app.pending_name, app.pending_count, .Delete, theme)
		} else {
			draw_delete_dialog(buffer, width, height, app.pending_name, theme)
		}
	} else if app.copying {
		draw_copy_progress_dialog(buffer, width, height, app.copy_name, app.copy_percent, theme)
	}
}

Bulk_Confirmation_Kind :: enum {
	Copy,
	Move,
	Delete,
}

draw_bulk_confirmation_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	entry_name: string,
	entry_count: int,
	kind: Bulk_Confirmation_Kind,
	theme: Theme,
) {
	title := "Potwierdzenie operacji"
	question := "Wykonać operację na oznaczonych elementach?"
	#partial switch kind {
	case .Copy:
		title = "Potwierdzenie kopiowania"
		question = "Cel już istnieje; nadpisać w całym zestawie?"
	case .Move:
		title = "Potwierdzenie przeniesienia"
		question = "Cel już istnieje; nadpisać w całym zestawie?"
	case .Delete:
		title = "Potwierdzenie usunięcia"
		question = "Czy na pewno usunąć oznaczony zestaw?"
	}
	dialog := dialog_open(buffer, width, height, 8, title, theme)
	dialog_write(dialog, 2, question)
	count_buffer: [64]byte
	count_text := fmt.bprintf(count_buffer[:], "Liczba elementów: %d", entry_count)
	dialog_write(dialog, 3, count_text, .Accent)
	dialog_write(dialog, 4, entry_name)
	dialog_write(dialog, 6, " Enter/T Tak   Esc/N Nie ", .Action)
}

draw_move_overwrite_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	entry_name: string,
	theme: Theme,
) {
	dialog := dialog_open(buffer, width, height, 7, "Potwierdzenie przeniesienia", theme)
	dialog_write(dialog, 2, "Element docelowy już istnieje:")
	dialog_write(dialog, 3, entry_name, .Accent)
	dialog_write(dialog, 5, " Enter/T Tak   Esc/N Nie   W Wszystkie ", .Action)
}

draw_delete_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	entry_name: string,
	theme: Theme,
) {
	dialog := dialog_open(buffer, width, height, 7, "Potwierdzenie usunięcia", theme)
	dialog_write(dialog, 2, "Czy na pewno usunąć?")
	dialog_write(dialog, 3, entry_name, .Accent)
	dialog_write(dialog, 5, " Enter/T Tak   Esc/N Nie   W Wszystkie ", .Action)
}

draw_overwrite_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	file_name: string,
	theme: Theme,
) {
	dialog := dialog_open(buffer, width, height, 7, "Potwierdzenie", theme)
	dialog_write(dialog, 2, "Element docelowy już istnieje:")
	dialog_write(dialog, 3, file_name, .Accent)
	dialog_write(dialog, 5, " Enter/T Tak   Esc/N Nie   W Wszystkie ", .Action)
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

	content_x := rect.x + 2
	content_width := max(rect.width - 4, 0)
	show_metadata :=
		content_width >=
		PANEL_MIN_NAME_WIDTH +
			PANEL_COLUMN_GAP +
			PANEL_SIZE_WIDTH +
			PANEL_COLUMN_GAP +
			PANEL_PERMISSIONS_WIDTH
	rows_y := rect.y + 1
	if show_metadata {
		permissions_x := content_x + content_width - PANEL_PERMISSIONS_WIDTH
		size_x := permissions_x - PANEL_COLUMN_GAP - PANEL_SIZE_WIDTH
		tui.buffer_write(buffer, content_x, rows_y, "Nazwa", border_style, size_x - content_x)
		tui.buffer_write(buffer, size_x, rows_y, "Rozmiar", border_style, PANEL_SIZE_WIDTH)
		tui.buffer_write(
			buffer,
			permissions_x,
			rows_y,
			"Uprawnienia",
			border_style,
			PANEL_PERMISSIONS_WIDTH,
		)
		rows_y += 1
	}

	visible_rows := max(rect.y + rect.height - 1 - rows_y, 0)
	if state.selected < state.offset {
		state.offset = state.selected
	} else if visible_rows > 0 && state.selected >= state.offset + visible_rows {
		state.offset = state.selected - visible_rows + 1
	}

	item_count := panel_item_count(state)
	for row in 0 ..< min(visible_rows, item_count - state.offset) {
		index := state.offset + row
		row_y := rows_y + row
		row_style := theme.panel_row_inactive
		if active {
			row_style = theme.panel_row_active
		}
		if active && index == state.selected {
			row_style = theme.selection_active
		} else if index == state.selected {
			row_style = theme.selection_inactive
		}
		marked := index > 0 && panel_is_marked(state, state.files[index - 1].name)
		if marked {
			row_style = theme.marked_inactive
			if active {
				row_style = theme.marked_active
			}
			if index == state.selected {
				row_style.attributes += {.Bold, .Underline}
			}
		}
		tui.buffer_fill(
			buffer,
			tui.Rect{x = rect.x + 1, y = row_y, width = rect.width - 2, height = 1},
			tui.Cell{character = ' ', style = row_style},
		)

		name := ".."
		name_buffer: [1024]byte
		size := "-"
		size_buffer: [16]byte
		permissions := "-"
		permissions_buffer: [9]byte
		if index > 0 {
			file := state.files[index - 1]
			if file.type == .Directory {
				name = fmt.bprintf(name_buffer[:], "[%s]", file.name)
			} else {
				name = file.name
			}
			size = format_file_size(size_buffer[:], file.size)
			permissions = format_permissions(permissions_buffer[:], file.mode)
		}

		name_width := content_width
		if show_metadata {
			permissions_x := content_x + content_width - PANEL_PERMISSIONS_WIDTH
			size_x := permissions_x - PANEL_COLUMN_GAP - PANEL_SIZE_WIDTH
			name_width = size_x - PANEL_COLUMN_GAP - content_x
			size_text_x := size_x + PANEL_SIZE_WIDTH - len(size)
			permissions_text_x := permissions_x + PANEL_PERMISSIONS_WIDTH - len(permissions)
			tui.buffer_write(buffer, size_text_x, row_y, size, row_style, PANEL_SIZE_WIDTH)
			tui.buffer_write(
				buffer,
				permissions_text_x,
				row_y,
				permissions,
				row_style,
				PANEL_PERMISSIONS_WIDTH,
			)
		}
		tui.buffer_write(buffer, content_x, row_y, name, row_style, name_width)
	}
}

format_file_size :: proc(buffer: []byte, size: i64) -> string {
	if size < 0 {
		return "-"
	}
	if size < 1024 {
		return fmt.bprintf(buffer, "%dB", size)
	}

	units := [?]string{"K", "M", "G", "T", "P", "E"}
	unit_index := 0
	divisor: i64 = 1024
	for unit_index < len(units) - 1 && size >= divisor * 1024 {
		divisor *= 1024
		unit_index += 1
	}

	whole := size / divisor
	if whole < 10 {
		remainder := u128(size % divisor)
		tenths := i64((remainder * 10 + u128(divisor) / 2) / u128(divisor))
		if tenths == 10 {
			whole += 1
			tenths = 0
		}
		return fmt.bprintf(buffer, "%d.%d%s", whole, tenths, units[unit_index])
	}

	rounded := whole
	if size % divisor >= (divisor + 1) / 2 {
		rounded += 1
	}
	return fmt.bprintf(buffer, "%d%s", rounded, units[unit_index])
}

format_permissions :: proc(buffer: []byte, permissions: os.Permissions) -> string {
	assert(len(buffer) >= 9)
	for &character in buffer[:9] {
		character = '-'
	}
	permission_character(buffer, 0, permissions, .Read_User, 'r')
	permission_character(buffer, 1, permissions, .Write_User, 'w')
	permission_character(buffer, 2, permissions, .Execute_User, 'x')
	permission_character(buffer, 3, permissions, .Read_Group, 'r')
	permission_character(buffer, 4, permissions, .Write_Group, 'w')
	permission_character(buffer, 5, permissions, .Execute_Group, 'x')
	permission_character(buffer, 6, permissions, .Read_Other, 'r')
	permission_character(buffer, 7, permissions, .Write_Other, 'w')
	permission_character(buffer, 8, permissions, .Execute_Other, 'x')
	return string(buffer[:9])
}

permission_character :: proc(
	buffer: []byte,
	index: int,
	permissions: os.Permissions,
	permission: os.Permission_Flag,
	character: byte,
) {
	if permission in permissions {
		buffer[index] = character
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
