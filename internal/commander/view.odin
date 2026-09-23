package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:internal/tui"

PANEL_ICON_WIDTH :: 1
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
		tui.buffer_write(buffer, 0, 0, tr("Terminal jest zbyt mały"), theme.dialog_accent)
		return
	}

	footer_height := 2
	left_width := width / 2
	panel_height := height - footer_height
	draw_panel_mode(
		buffer,
		tui.Rect{x = 0, y = 0, width = left_width, height = panel_height},
		app,
		0,
		theme,
	)
	draw_panel_mode(
		buffer,
		tui.Rect{x = left_width, y = 0, width = width - left_width, height = panel_height},
		app,
		1,
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
			tr("%s %s: %d%%"),
			app.operation_label,
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
		footer_labels(width),
		theme.keys,
		width,
	)

	if app.viewer_pending {
		draw_viewer(buffer, width, height, app, theme)
	} else if app.link_edit_pending {
		kind := tr("symboliczny")
		if app.link_hard do kind = tr("twardy")
		hint := fmt.aprintf(tr("Typ: %s (Tab przełącza); cel: drugi panel"), kind)
		defer delete(hint)
		draw_name_edit_dialog(buffer, width, height, app.link_name, app.link_name_cursor,
			tr("Utwórz link"), tr("Enter Utwórz"), theme, tr("Nazwa linku:"), hint)
	} else if app.checksum_pending {
		draw_checksum_dialog(buffer, width, height, app, theme)
	} else if app.background_pending {
		draw_background_dialog(buffer, width, height, app, theme)
	} else if app.help_pending {
		draw_help_dialog(buffer, width, height, theme, app.help_offset)
	} else if app.menu_kind != .None {
		draw_menu_dialog(buffer, width, height, app, theme)
	} else if app.remote_edit_pending {
		draw_name_edit_dialog(buffer, width, height, app.remote_text, app.remote_cursor,
			tr("Połącz SFTP/FTP"), tr("Enter Połącz"), theme,
			tr("Zdalny katalog skonfigurowany w rclone (nazwa:ścieżka):"),
			tr("Wymaga zainstalowanego rclone i skonfigurowanego SFTP/FTP"))
	} else if app.sync_pending {
		draw_sync_dialog(buffer, width, height, app, theme)
	} else if app.command_edit_pending {
		draw_name_edit_dialog(buffer, width, height, app.command_text, app.command_cursor,
			tr("Polecenie powłoki"), tr("Enter Wykonaj"), theme,
			tr("Polecenie w katalogu aktywnego panelu:"))
	} else if app.exit_pending {
		draw_exit_dialog(buffer, width, height, theme)
	} else if app.create_edit_pending {
		draw_name_edit_dialog(buffer, width, height, app.create_name, app.create_name_cursor,
			tr("Utwórz plik / katalog"), tr("Enter Utwórz"), theme,
			tr("Nazwa w aktywnym katalogu:"), tr("Ukośnik / = katalog (mkdir -p), bez / = plik"))
	} else if app.filter_edit_pending {
		draw_name_edit_dialog(buffer, width, height, app.filter_text, app.filter_cursor,
			tr("Filtr panelu"), tr("Enter Zastosuj"), theme,
			tr("Fragment nazwy (puste = bez filtra):"))
	} else if app.mark_edit_pending {
		title := tr("Oznacz grupę")
		action := tr("Enter Oznacz")
		if app.mark_mode == .Unselect {
			title = tr("Odznacz grupę")
			action = tr("Enter Odznacz")
		}
		draw_name_edit_dialog(buffer, width, height, app.mark_pattern, app.mark_pattern_cursor,
			title, action, theme, tr("Wzorzec (* i ?):"))
	} else if app.search_edit_pending {
		prompt := tr("Fragment nazwy (rekurencyjnie):")
		hint := tr("Tab: wyszukiwanie w treści")
		if app.search_contents {
			prompt = tr("Tekst w plikach (rekurencyjnie):")
			hint = tr("Tab: wyszukiwanie po nazwie")
		}
		draw_name_edit_dialog(buffer, width, height, app.search_query, app.search_query_cursor,
			tr("Znajdź plik"), tr("Enter Szukaj"), theme,
			prompt, hint)
	} else if app.search_results_pending {
		draw_search_results_dialog(buffer, width, height, app, theme)
	} else if app.properties_pending {
		draw_properties_dialog(buffer, width, height, app, theme)
	} else if app.bookmarks_pending {
		draw_bookmarks_dialog(buffer, width, height, app, theme)
	} else if app.overwrite_pending {
		if app.pending_count > 1 {
			draw_bulk_confirmation_dialog(buffer, width, height, app.copy_name, app.pending_count, .Copy, theme)
		} else {
			draw_overwrite_dialog(buffer, width, height, app.copy_name, theme)
		}
	} else if app.copy_edit_pending {
		draw_name_edit_dialog(
			buffer,
			width,
			height,
			app.copy_target_name,
			app.copy_name_cursor,
			tr("Kopiuj jako"),
			tr("Enter Kopiuj"),
			theme,
		)
	} else if app.move_edit_pending {
		draw_move_edit_dialog(buffer, width, height, app.move_name, app.move_name_cursor, theme)
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
		draw_copy_progress_dialog(buffer, width, height, app.copy_name, app.copy_percent, theme, app.operation_label)
	}
}

footer_labels :: proc(width: int) -> string {
	full := tr("[F1] Pomoc  [F2] Menu użytkownika  [F3] Podgląd  [F4] Edycja  [F5] Kopiuj  [F6] Przenieś  [F7] Utwórz  [F8] Usuń  [F9] Menu główne  [Esc/F10] Koniec")
	if strings.rune_count(full) <= width do return full
	compact := tr("[F1] Pom  [F2] Menu użytkownika  [F3] Podgl  [F4] Edyt  [F5] Kop  [F6] Przen  [F7] Utw  [F8] Usuń  [F9] Menu główne  [Esc] Wyjdź")
	if strings.rune_count(compact) <= width do return compact
	return tr("[F1] Pomoc  [F2] Menu użytkownika  [F3] Podgl.  [F9] Menu główne  [Esc] Wyjdź")
}

draw_search_results_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	app: ^App_State,
	theme: Theme,
) {
	dialog_height := min(18, height - 2)
	dialog := dialog_open(buffer, width, height, dialog_height, tr("Wyniki wyszukiwania"), theme)
	count_text := fmt.aprintf(tr("Wyniki: %d dla %s"), len(app.search_results), app.search_query)
	defer delete(count_text)
	dialog_write(dialog, 1, count_text)
	visible := max(dialog_height - 5, 1)
	offset := 0
	if app.search_selected >= visible do offset = app.search_selected - visible + 1
	for row in 0 ..< min(visible, len(app.search_results) - offset) {
		index := offset + row
		path := app.search_results[index]
		label := path
		if strings.has_prefix(path, app.search_root) {
			start := len(app.search_root)
			if start < len(path) && path[start] == os.Path_Separator do start += 1
			if start < len(path) do label = path[start:]
		}
		style := theme.dialog_surface
		if index == app.search_selected do style = theme.dialog_accent
		tui.buffer_fill(buffer, tui.Rect{x = dialog.rect.x + 2, y = dialog.rect.y + 2 + row,
			width = dialog.rect.width - 4, height = 1}, tui.Cell{character = ' ', style = style})
		tui.buffer_write(buffer, dialog.rect.x + 3, dialog.rect.y + 2 + row, label, style, dialog.rect.width - 6)
	}
	dialog_write(dialog, dialog_height - 2, tr(" Enter Otwórz   Esc Zamknij "), .Action)
}

draw_properties_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	app: ^App_State,
	theme: Theme,
) {
	dialog := dialog_open(buffer, width, height, 18, tr("Właściwości"), theme)
	dialog_write(dialog, 1, app.property_name, .Accent)
	path_text := fmt.aprintf(tr("Ścieżka: %s"), app.property_path)
	type_text := fmt.aprintf(tr("Typ: %s"), app.property_kind)
	size_buffer: [32]byte
	size_text := fmt.aprintf(tr("Rozmiar: %s (%d bajtów)"), format_file_size(size_buffer[:], app.property_size), app.property_size)
	modified_text := fmt.aprintf(tr("Modyfikacja: %s"), app.property_modified)
	accessed_text := fmt.aprintf(tr("Ostatni dostęp: %s"), app.property_accessed)
	created_text := fmt.aprintf(tr("Utworzenie: %s"), app.property_created)
	owner_text := fmt.aprintf(tr("Właściciel: %s"), app.property_owner)
	group_text := fmt.aprintf(tr("Grupa: %s"), app.property_group)
	defer delete(path_text)
	defer delete(type_text)
	defer delete(size_text)
	defer delete(modified_text)
	defer delete(accessed_text)
	defer delete(created_text)
	defer delete(owner_text)
	defer delete(group_text)
	dialog_write(dialog, 3, path_text)
	dialog_write(dialog, 4, type_text)
	dialog_write(dialog, 5, size_text)
	dialog_write(dialog, 6, modified_text)
	dialog_write(dialog, 7, accessed_text)
	dialog_write(dialog, 8, created_text)
	dialog_write(dialog, 9, owner_text)
	dialog_write(dialog, 10, group_text)
	dialog_write(dialog, 12, tr("Uprawnienia ósemkowe:"))
	if app.property_is_symlink {
		dialog_write(dialog, 13, app.property_mode, .Accent)
		dialog_write(dialog, 14, tr("Link symboliczny: zmiana trybu jest wyłączona"))
		dialog_write(dialog, 16, tr(" Enter/Esc Zamknij "), .Action)
		return
	}
	field := tui.Rect{x = dialog.rect.x + 27, y = dialog.rect.y + 12, width = 8, height = 1}
	tui.buffer_fill(buffer, field, tui.Cell{character = ' ', style = theme.dialog_accent})
	tui.buffer_write(buffer, field.x, field.y, app.property_mode, theme.dialog_accent, field.width)
	cursor := clamp(app.property_mode_cursor, 0, len(app.property_mode))
	if cursor < field.width {
		cell := tui.buffer_get(buffer, field.x + cursor, field.y)
		cell.style = theme.dialog_action
		tui.buffer_set(buffer, field.x + cursor, field.y, cell)
	}
	dialog_write(dialog, 16, tr(" Enter Zapisz   Esc Anuluj "), .Action)
}

HELP_LINE_COUNT :: 23

help_max_offset :: proc(ctx: ^tui.Context) -> int {
	_, height := tui.size(ctx)
	dialog_height := min(HELP_LINE_COUNT + 4, height - 2)
	return max(HELP_LINE_COUNT - max(dialog_height - 3, 0), 0)
}

draw_help_dialog :: proc(buffer: ^tui.Buffer, width, height: int, theme: Theme, offset := 0) {
	lines := []string{
		tr("Nawigacja"),
		tr("  Tab / ↑↓    panel / zaznaczenie"),
		tr("  Enter / ←→  katalog / historia"),
		tr("Operacje na plikach"),
		tr("  F3 / F4     podgląd / edycja"),
		tr("  F5 / F6     kopiuj / przenieś"),
		tr("  F7 / F8     utwórz / usuń"),
		tr("Wyszukiwanie i informacje"),
		tr("  Alt-F7 / ^G szukaj; Tab: nazwa / treść"),
		tr("  ^P / ^B     właściwości / zakładki"),
		tr("  ^Q / ^U     porównaj / oblicz rozmiar"),
		tr("  ^K / ^L     suma kontrolna / utwórz link"),
		tr("Powłoka i widok"),
		tr("  : / ^O      polecenie / powłoka"),
		tr("  ^J / ^T     kopiuj w tle / kolejka"),
		tr("  / / ^D      filtr / pliki ukryte"),
		tr("  ^R / ^S     odśwież / zmień sortowanie"),
		tr("  + \\ *       oznacz / odznacz / odwróć"),
		tr("  Esc / F10   zakończ program"),
		tr("Etap 5"),
		tr("  F11 / F12   tryb panelu / porównaj rekurencyjnie"),
		tr("  ^Y / ^N     synchronizuj / połącz SFTP/FTP"),
		tr("  Mysz        wybór, podwójny klik, przewijanie"),
	}
	dialog_height := min(len(lines) + 4, height - 2)
	dialog := dialog_open(buffer, width, height, dialog_height, tr("Pomoc Twin Commander"), theme)
	visible_lines := min(len(lines), max(dialog_height - 3, 0))
	start_offset := clamp(offset, 0, max(len(lines) - visible_lines, 0))
	for row in 0 ..< visible_lines {
		index := start_offset + row
		line := lines[index]
		role := Dialog_Text_Role.Body
		if index == 0 || index == 3 || index == 7 || index == 12 || index == 19 do role = .Accent
		dialog_write(dialog, 1 + row, line, role)
	}
	dialog_write(dialog, dialog_height - 2, tr(" ↑↓ Przewiń   Enter/Esc Zamknij "), .Action)
}

draw_menu_dialog :: proc(buffer: ^tui.Buffer, width, height: int, app: ^App_State, theme: Theme) {
	title := tr("Menu główne")
	count := len(MAIN_MENU_ITEMS)
	if app.menu_kind == .User {
		title = tr("Menu użytkownika")
		count = len(USER_MENU_ITEMS)
	}
	dialog_height := min(count + 4, height - 2)
	dialog := dialog_open(buffer, width, height, dialog_height, title, theme)
	visible := max(dialog_height - 3, 1)
	offset := max(app.menu_selected - visible + 1, 0)
	for row in 0 ..< min(visible, count - offset) {
		index := offset + row
		item := menu_item(app.menu_kind, index)
		style := theme.dialog_surface
		if index == app.menu_selected do style = theme.dialog_accent
		tui.buffer_fill(buffer, tui.Rect{x = dialog.rect.x + 2, y = dialog.rect.y + 1 + row,
			width = dialog.rect.width - 4, height = 1}, tui.Cell{character = ' ', style = style})
		tui.buffer_write(buffer, dialog.rect.x + 3, dialog.rect.y + 1 + row, tr(item), style, dialog.rect.width - 6)
	}
	dialog_write(dialog, dialog_height - 2, tr(" Enter Wybierz   Esc Zamknij "), .Action)
}

draw_bookmarks_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	app: ^App_State,
	theme: Theme,
) {
	dialog_height := min(16, height - 2)
	dialog := dialog_open(buffer, width, height, dialog_height, tr("Zakładki katalogów"), theme)
	visible := max(dialog_height - 4, 1)
	offset := 0
	if app.bookmark_selected >= visible do offset = app.bookmark_selected - visible + 1
	if len(app.bookmarks) == 0 {
		dialog_write(dialog, 2, tr("Brak zakładek. Naciśnij A, aby dodać bieżący katalog."))
	}
	for row in 0 ..< min(visible, len(app.bookmarks) - offset) {
		index := offset + row
		style := theme.dialog_surface
		if index == app.bookmark_selected do style = theme.dialog_accent
		tui.buffer_fill(buffer, tui.Rect{x = dialog.rect.x + 2, y = dialog.rect.y + 1 + row,
			width = dialog.rect.width - 4, height = 1}, tui.Cell{character = ' ', style = style})
		tui.buffer_write(buffer, dialog.rect.x + 3, dialog.rect.y + 1 + row,
			app.bookmarks[index], style, dialog.rect.width - 6)
	}
	dialog_write(dialog, dialog_height - 2, tr(" A Dodaj   D Usuń   Enter Otwórz   Esc Zamknij "), .Action)
}

draw_exit_dialog :: proc(buffer: ^tui.Buffer, width, height: int, theme: Theme) {
	dialog := dialog_open(buffer, width, height, 6, tr("Potwierdzenie wyjścia"), theme)
	dialog_write(dialog, 2, tr("Czy na pewno zakończyć program?"))
	dialog_write(dialog, 4, tr(" Enter/T Tak   Esc/N Nie "), .Action)
}

draw_move_edit_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	entry_name: string,
	cursor: int,
	theme: Theme,
) {
	draw_name_edit_dialog(
		buffer,
		width,
		height,
		entry_name,
		cursor,
		tr("Przenieś / zmień nazwę"),
		tr("Enter Przenieś"),
		theme,
	)
}

draw_name_edit_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	entry_name: string,
	cursor: int,
	title, submit_label: string,
	theme: Theme,
	prompt: string = "",
	hint: string = "",
) {
	dialog := dialog_open(buffer, width, height, 8, title, theme)
	label := prompt
	if len(label) == 0 do label = tr("Nazwa w katalogu docelowym:")
	dialog_write(dialog, 2, label)
	dialog_write(dialog, 4, hint)
	field := tui.Rect {
		x = dialog.rect.x + 3,
		y = dialog.rect.y + 3,
		width = dialog.rect.width - 6,
		height = 1,
	}
	tui.buffer_fill(buffer, field, tui.Cell{character = ' ', style = theme.dialog_accent})
	tui.buffer_write(buffer, field.x, field.y, entry_name, theme.dialog_accent, field.width)
	bounded_cursor := clamp(cursor, 0, len(entry_name))
	cursor_width := tui.buffer_write(buffer, field.x, field.y, entry_name[:bounded_cursor], theme.dialog_accent, field.width)
	if cursor_width < field.width {
		cursor_cell := tui.buffer_get(buffer, field.x + cursor_width, field.y)
		cursor_cell.style = theme.dialog_action
		tui.buffer_set(buffer, field.x + cursor_width, field.y, cursor_cell)
	}
	actions := fmt.aprintf(tr(" %s   Esc Anuluj "), submit_label)
	defer delete(actions)
	dialog_write(dialog, 6, actions, .Action)
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
	title := tr("Potwierdzenie operacji")
	question := tr("Wykonać operację na oznaczonych elementach?")
	#partial switch kind {
	case .Copy:
		title = tr("Potwierdzenie kopiowania")
		question = tr("Cel już istnieje; nadpisać w całym zestawie?")
	case .Move:
		title = tr("Potwierdzenie przeniesienia")
		question = tr("Cel już istnieje; nadpisać w całym zestawie?")
	case .Delete:
		title = tr("Potwierdzenie usunięcia")
		question = tr("Czy na pewno usunąć oznaczony zestaw?")
	}
	dialog := dialog_open(buffer, width, height, 8, title, theme)
	dialog_write(dialog, 2, question)
	count_buffer: [64]byte
	count_text := fmt.bprintf(count_buffer[:], tr("Liczba elementów: %d"), entry_count)
	dialog_write(dialog, 3, count_text, .Accent)
	dialog_write(dialog, 4, entry_name)
	dialog_write(dialog, 6, tr(" Enter/T Tak   Esc/N Nie "), .Action)
}

draw_move_overwrite_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	entry_name: string,
	theme: Theme,
) {
	dialog := dialog_open(buffer, width, height, 7, tr("Potwierdzenie przeniesienia"), theme)
	dialog_write(dialog, 2, tr("Element docelowy już istnieje:"))
	dialog_write(dialog, 3, entry_name, .Accent)
	dialog_write(dialog, 5, tr(" Enter/T Tak   Esc/N Nie   W Wszystkie "), .Action)
}

draw_delete_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	entry_name: string,
	theme: Theme,
) {
	dialog := dialog_open(buffer, width, height, 7, tr("Potwierdzenie usunięcia"), theme)
	dialog_write(dialog, 2, tr("Czy na pewno usunąć?"))
	dialog_write(dialog, 3, entry_name, .Accent)
	dialog_write(dialog, 5, tr(" Enter/T Tak   Esc/N Nie   W Wszystkie "), .Action)
}

draw_overwrite_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	file_name: string,
	theme: Theme,
) {
	dialog := dialog_open(buffer, width, height, 7, tr("Potwierdzenie"), theme)
	dialog_write(dialog, 2, tr("Element docelowy już istnieje:"))
	dialog_write(dialog, 3, file_name, .Accent)
	dialog_write(dialog, 5, tr(" Enter/T Tak   Esc/N Nie   W Wszystkie "), .Action)
}

draw_copy_progress_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	file_name: string,
	percent: int,
	theme: Theme,
	operation_label: string = "Kopiowanie",
) {
	dialog := dialog_open(buffer, width, height, 7, operation_label, theme)
	dialog_write(dialog, 2, file_name)
	dialog_progress(dialog, 4, percent)
	percent_text: [16]byte
	text := fmt.bprintf(percent_text[:], "%d%%", percent)
	text_x := dialog.rect.x + (dialog.rect.width - len(text)) / 2
	tui.buffer_write(buffer, text_x, dialog.rect.y + 5, text, theme.dialog_accent)
}

draw_operation_error_dialog :: proc(
	buffer: ^tui.Buffer,
	width, height: int,
	entry_name, message: string,
	theme: Theme,
) {
	dialog := dialog_open(buffer, width, height, 9, tr("Błąd operacji"), theme)
	dialog_write(dialog, 2, entry_name, .Accent)
	dialog_write(dialog, 4, message)
	dialog_write(dialog, 7, tr(" R Ponów   P Pomiń   Esc/A Przerwij "), .Action)
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
	name_x := content_x + PANEL_ICON_WIDTH + PANEL_COLUMN_GAP
	show_metadata :=
		content_width >=
		PANEL_ICON_WIDTH +
			PANEL_COLUMN_GAP +
		PANEL_MIN_NAME_WIDTH +
			PANEL_COLUMN_GAP +
			PANEL_SIZE_WIDTH +
			PANEL_COLUMN_GAP +
			PANEL_PERMISSIONS_WIDTH
	rows_y := rect.y + 1
	if show_metadata {
		permissions_x := content_x + content_width - PANEL_PERMISSIONS_WIDTH
		size_x := permissions_x - PANEL_COLUMN_GAP - PANEL_SIZE_WIDTH
		tui.buffer_write(buffer, name_x, rows_y, tr("Nazwa"), border_style, size_x - name_x)
		tui.buffer_write(buffer, size_x, rows_y, tr("Rozmiar"), border_style, PANEL_SIZE_WIDTH)
		tui.buffer_write(
			buffer,
			permissions_x,
			rows_y,
			tr("Uprawnienia"),
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

		icon := rune('↰')
		name := ".."
		size := "-"
		size_buffer: [16]byte
		permissions := "-"
		permissions_buffer: [9]byte
		if index > 0 {
			file := state.files[index - 1]
			icon = file_type_icon(file)
			name = file.name
			size = format_file_size(size_buffer[:], file.size)
			permissions = format_permissions(permissions_buffer[:], file.mode)
		}

		name_width := max(content_width - PANEL_ICON_WIDTH - PANEL_COLUMN_GAP, 0)
		if show_metadata {
			permissions_x := content_x + content_width - PANEL_PERMISSIONS_WIDTH
			size_x := permissions_x - PANEL_COLUMN_GAP - PANEL_SIZE_WIDTH
			name_width = size_x - PANEL_COLUMN_GAP - name_x
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
		tui.buffer_set(buffer, content_x, row_y, tui.Cell{character = icon, style = row_style})
		tui.buffer_write(buffer, name_x, row_y, name, row_style, name_width)
	}
	if state.space_known && rect.width >= 24 {
		free_buffer: [24]byte
		total_buffer: [24]byte
		space_text := fmt.aprintf(
			tr(" wolne %s / %s "),
			format_file_size(free_buffer[:], state.free_bytes),
			format_file_size(total_buffer[:], state.total_bytes),
		)
		defer delete(space_text)
		space_x := max(rect.x + rect.width - 2 - len(space_text), rect.x + 1)
		tui.buffer_write(buffer, space_x, rect.y + rect.height - 1, space_text, border_style, rect.x + rect.width - 1 - space_x)
	}
}

file_type_icon :: proc(file: os.File_Info) -> rune {
	switch file.type {
	case .Directory:
		return '▸'
	case .Symlink:
		return '↗'
	case .Named_Pipe:
		return '│'
	case .Socket:
		return '◉'
	case .Block_Device, .Character_Device:
		return '■'
	case .Undetermined:
		return '?'
	case .Regular:
	}

	extension := filepath.ext(file.name)
	if extension_matches(extension, []string{".c", ".cc", ".cpp", ".css", ".go", ".h", ".hpp", ".html", ".java", ".js", ".jsx", ".odin", ".php", ".py", ".rb", ".rs", ".sh", ".swift", ".ts", ".tsx"}) {
		return 'λ'
	}
	if extension_matches(extension, []string{".bmp", ".gif", ".heic", ".jpeg", ".jpg", ".png", ".svg", ".tif", ".tiff", ".webp"}) {
		return '◈'
	}
	if extension_matches(extension, []string{".7z", ".bz2", ".gz", ".rar", ".tar", ".tgz", ".xz", ".zip"}) {
		return '▣'
	}
	if extension_matches(extension, []string{".aac", ".flac", ".m4a", ".mp3", ".ogg", ".wav"}) {
		return '♪'
	}
	if extension_matches(extension, []string{".avi", ".m4v", ".mkv", ".mov", ".mp4", ".webm"}) {
		return '▶'
	}
	if extension_matches(extension, []string{".csv", ".db", ".json", ".sql", ".toml", ".tsv", ".xml", ".yaml", ".yml"}) {
		return '▦'
	}
	if extension_matches(extension, []string{".doc", ".docx", ".odt", ".pdf", ".ppt", ".pptx", ".xls", ".xlsx"}) {
		return '¶'
	}
	if extension_matches(extension, []string{".log", ".md", ".rst", ".txt"}) {
		return '≡'
	}
	if strings.equal_fold(file.name, "Makefile") || strings.equal_fold(file.name, "Dockerfile") {
		return 'λ'
	}
	return '·'
}

extension_matches :: proc(extension: string, candidates: []string) -> bool {
	for candidate in candidates {
		if strings.equal_fold(extension, candidate) {
			return true
		}
	}
	return false
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
