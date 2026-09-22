package commander

import "core:fmt"
import "core:os"
import "core:strings"
import "tc:internal/tui"

MAX_VIEWER_SIZE :: 64 * 1024 * 1024
HEX_BYTES_PER_ROW :: 16

begin_viewer :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	if panel.selected <= 0 || panel.selected > len(panel.files) {
		set_status(app, strings.clone(tr("Wybierz plik")) or_else "")
		return
	}
	file := panel.files[panel.selected - 1]
	if file.type != .Regular {
		set_status(app, fmt.aprintf(tr("%s nie jest zwykłym plikiem"), file.name))
		return
	}
	if file.size > MAX_VIEWER_SIZE {
		set_status(app, fmt.aprintf(tr("Plik jest zbyt duży dla podglądu (%d MiB limit)"), MAX_VIEWER_SIZE / 1024 / 1024))
		return
	}
	data: []byte
	err: os.Error
	if panel.remote {
		ok: bool
		limit := fmt.aprintf("%d", MAX_VIEWER_SIZE + 1)
		defer delete(limit)
		data, ok = remote_run([]string{"cat", "--count", limit, file.fullpath})
		if !ok do err = .Invalid_Command
	} else {
		data, err = os.read_entire_file(file.fullpath, context.allocator)
	}
	if err != nil {
		set_status(app, fmt.aprintf(tr("Nie można odczytać pliku: %s"), os.error_string(err)))
		return
	}
	if len(data) > MAX_VIEWER_SIZE {
		delete(data)
		set_status(app, fmt.aprintf(tr("Plik jest zbyt duży dla podglądu (%d MiB limit)"), MAX_VIEWER_SIZE / 1024 / 1024))
		return
	}
	clear_viewer(app)
	app.viewer_data = data
	app.viewer_path = strings.clone(file.fullpath) or_else ""
	viewer_index_lines(data, &app.viewer_line_starts)
	if strings.equal_fold(file.name[max(len(file.name) - 5, 0):], ".json") && len(data) <= 8 * 1024 * 1024 {
		formatted, valid := viewer_pretty_json(data)
		if valid {
			app.viewer_formatted_data = formatted
			viewer_index_lines(formatted, &app.viewer_formatted_line_starts)
			app.viewer_json_available = true
			app.viewer_syntax = true
		}
	}
	app.viewer_pending = true
}

viewer_index_lines :: proc(data: []byte, lines: ^[dynamic]int) {
	append(lines, 0)
	for byte, index in data {
		if byte == '\n' && index + 1 < len(data) do append(lines, index + 1)
	}
}

viewer_active_data :: proc(app: ^App_State) -> []byte {
	if app.viewer_formatted && !app.viewer_hex do return app.viewer_formatted_data
	return app.viewer_data
}

viewer_active_lines :: proc(app: ^App_State) -> []int {
	if app.viewer_formatted && !app.viewer_hex do return app.viewer_formatted_line_starts[:]
	return app.viewer_line_starts[:]
}

clear_viewer :: proc(app: ^App_State) {
	delete(app.viewer_path)
	delete(app.viewer_data)
	delete(app.viewer_line_starts)
	delete(app.viewer_formatted_data)
	delete(app.viewer_formatted_line_starts)
	delete(app.viewer_query)
	app.viewer_path = ""
	app.viewer_data = nil
	app.viewer_line_starts = nil
	app.viewer_formatted_data = nil
	app.viewer_formatted_line_starts = nil
	app.viewer_json_available = false
	app.viewer_formatted = false
	app.viewer_syntax = false
	app.viewer_query = ""
	app.viewer_query_cursor = 0
	app.viewer_top = 0
	app.viewer_hex = false
	app.viewer_search_edit_pending = false
	app.viewer_pending = false
}

handle_viewer_event :: proc(ctx: ^tui.Context, app: ^App_State, event: tui.Event) {
	if app.viewer_search_edit_pending {
		switch handle_name_edit_input(&app.viewer_query, &app.viewer_query_cursor, event, true) {
		case .Cancel: app.viewer_search_edit_pending = false
		case .Submit:
			app.viewer_search_edit_pending = false
			viewer_find_next(app)
		case .None:
		}
		return
	}
	if event.kind == .Key {
		_, height := tui.size(ctx)
		page := max(height - 5, 1)
		#partial switch event.key {
		case .Escape, .F3: clear_viewer(app)
		case .Up: app.viewer_top = max(app.viewer_top - 1, 0)
		case .Down: viewer_move(app, 1)
		case .Page_Up: app.viewer_top = max(app.viewer_top - page, 0)
		case .Page_Down: viewer_move(app, page)
		case .Home: app.viewer_top = 0
		case .End: app.viewer_top = viewer_max_top(app)
		case .F4:
			app.viewer_hex = !app.viewer_hex
			app.viewer_top = 0
		case .F7: begin_viewer_search(app)
		case .F5: viewer_toggle_format(app)
		case .F6: viewer_toggle_syntax(app)
		case:
		}
		return
	}
	if event.kind == .Text && event.modifiers == {} {
		switch event.text {
		case '/': begin_viewer_search(app)
		case 'n', 'N': viewer_find_next(app)
		case 'h', 'H':
			app.viewer_hex = !app.viewer_hex
			app.viewer_top = 0
		case 'f', 'F': viewer_toggle_format(app)
		case 'c', 'C': viewer_toggle_syntax(app)
		case:
		}
	}
}

viewer_toggle_format :: proc(app: ^App_State) {
	if !app.viewer_json_available {
		set_status(app, strings.clone(tr("Nie można sformatować: plik nie jest poprawnym JSON-em lub jest zbyt duży")) or_else "")
		return
	}
	app.viewer_formatted = !app.viewer_formatted
	app.viewer_top = 0
}

viewer_toggle_syntax :: proc(app: ^App_State) {
	if !app.viewer_json_available do return
	app.viewer_syntax = !app.viewer_syntax
}

begin_viewer_search :: proc(app: ^App_State) {
	app.viewer_search_edit_pending = true
	app.viewer_query_cursor = len(app.viewer_query)
}

viewer_max_top :: proc(app: ^App_State) -> int {
	if app.viewer_hex do return max((len(app.viewer_data) + HEX_BYTES_PER_ROW - 1) / HEX_BYTES_PER_ROW - 1, 0)
	return max(len(viewer_active_lines(app)) - 1, 0)
}

viewer_move :: proc(app: ^App_State, delta: int) {
	app.viewer_top = clamp(app.viewer_top + delta, 0, viewer_max_top(app))
}

viewer_find_next :: proc(app: ^App_State) -> bool {
	if len(app.viewer_query) == 0 do return false
	data := viewer_active_data(app)
	lines := viewer_active_lines(app)
	start := 0
	if app.viewer_hex {
		start = min((app.viewer_top + 1) * HEX_BYTES_PER_ROW, len(app.viewer_data))
	} else if app.viewer_top + 1 < len(lines) {
		start = lines[app.viewer_top + 1]
	}
	match := find_bytes_fold(data, transmute([]byte)app.viewer_query, start)
	if match < 0 && start > 0 do match = find_bytes_fold(data, transmute([]byte)app.viewer_query, 0)
	if match < 0 {
		set_status(app, fmt.aprintf(tr("Nie znaleziono: %s"), app.viewer_query))
		return false
	}
	if app.viewer_hex {
		app.viewer_top = match / HEX_BYTES_PER_ROW
	} else {
		line := 0
		for offset, index in lines {
			if offset > match do break
			line = index
		}
		app.viewer_top = line
	}
	set_status(app, fmt.aprintf(tr("Znaleziono: %s"), app.viewer_query))
	return true
}

find_bytes_fold :: proc(data, needle: []byte, start: int) -> int {
	if len(needle) == 0 || start < 0 || start > len(data) - len(needle) do return -1
	for index in start ..< len(data) - len(needle) + 1 {
		matched := true
		for offset in 0 ..< len(needle) {
			left := data[index + offset]
			right := needle[offset]
			if left >= 'A' && left <= 'Z' do left += 'a' - 'A'
			if right >= 'A' && right <= 'Z' do right += 'a' - 'A'
			if left != right {
				matched = false
				break
			}
		}
		if matched do return index
	}
	return -1
}

draw_viewer :: proc(buffer: ^tui.Buffer, width, height: int, app: ^App_State, theme: Theme) {
	rect := tui.Rect{x = 1, y = 1, width = width - 2, height = height - 2}
	tui.buffer_fill(buffer, rect, tui.Cell{character = ' ', style = theme.dialog_surface})
	draw_box(buffer, rect, theme.dialog_border)
	title := fmt.aprintf(tr(" Podgląd: %s "), app.viewer_path)
	defer delete(title)
	tui.buffer_write(buffer, rect.x + 2, rect.y, title, theme.dialog_border, rect.width - 4)
	rows := max(rect.height - 3, 0)
	if app.viewer_hex {
		draw_viewer_hex(buffer, rect, app, theme, rows)
	} else {
		draw_viewer_text(buffer, rect, app, theme, rows)
	}
	mode := tr("tekst")
	if app.viewer_hex do mode = tr("hex")
	if app.viewer_formatted && !app.viewer_hex do mode = tr("JSON formatowany")
	footer := fmt.aprintf(tr(" Tryb: %s | [F4/H] przełącz | [F7 lub /] szukaj | [N] następny | [F3/Esc] zamknij "), mode)
	footer_width := rect.width - 4
	if strings.rune_count(footer) > footer_width {
		delete(footer)
		footer = fmt.aprintf(tr(" %s | [F4/H] tryb | [/] szukaj | [N] dalej | [Esc] zamknij "), mode)
	}
	if app.viewer_json_available && !app.viewer_hex {
		delete(footer)
		footer = strings.clone(tr(" [F5] format [F6] kolory [/] szukaj [Esc] zamknij ")) or_else ""
		if strings.rune_count(footer) > footer_width {
			delete(footer)
			footer = strings.clone(tr(" [F5] fmt [F6] kolor [Esc] zamknij ")) or_else ""
		}
		if strings.rune_count(footer) > footer_width {
			delete(footer)
			footer = strings.clone(tr("[Esc] zamknij")) or_else ""
		}
	}
	if strings.rune_count(footer) > footer_width {
		delete(footer)
		footer = fmt.aprintf(tr(" %s | [H] tryb | [/] szukaj | [Esc] zamknij "), mode)
	}
	if strings.rune_count(footer) > footer_width {
		delete(footer)
		footer = strings.clone(tr("[Esc] zamknij")) or_else ""
	}
	defer delete(footer)
	tui.buffer_write(buffer, rect.x + 2, rect.y + rect.height - 1, footer, theme.dialog_action, footer_width)
	if app.viewer_search_edit_pending {
		draw_name_edit_dialog(buffer, width, height, app.viewer_query, app.viewer_query_cursor,
			tr("Szukaj w podglądzie"), tr("Enter Szukaj"), theme, tr("Tekst:"))
	}
}

draw_viewer_text :: proc(buffer: ^tui.Buffer, rect: tui.Rect, app: ^App_State, theme: Theme, rows: int) {
	data := viewer_active_data(app)
	lines := viewer_active_lines(app)
	for row in 0 ..< rows {
		line_index := app.viewer_top + row
		if line_index >= len(lines) do break
		start := lines[line_index]
		end := len(data)
		if line_index + 1 < len(lines) do end = lines[line_index + 1] - 1
		if end > start && data[end - 1] == '\r' do end -= 1
		number_buffer: [16]byte
		number := fmt.bprintf(number_buffer[:], "%6d ", line_index + 1)
		tui.buffer_write(buffer, rect.x + 2, rect.y + 1 + row, number, theme.dialog_accent, 7)
		clean: [4096]byte
		count := min(end - start, len(clean))
		for index in 0 ..< count {
			byte := data[start + index]
			if byte < 32 || byte == 127 { byte = ' ' }
			clean[index] = byte
		}
		if app.viewer_json_available && app.viewer_syntax {
			viewer_draw_json_line(buffer, rect.x + 9, rect.y + 1 + row, string(clean[:count]), rect.width - 11, theme)
		} else {
			tui.buffer_write(buffer, rect.x + 9, rect.y + 1 + row, string(clean[:count]), theme.dialog_surface, rect.width - 11)
		}
	}
}

draw_viewer_hex :: proc(buffer: ^tui.Buffer, rect: tui.Rect, app: ^App_State, theme: Theme, rows: int) {
	for row in 0 ..< rows {
		offset := (app.viewer_top + row) * HEX_BYTES_PER_ROW
		if offset >= len(app.viewer_data) do break
		line: [96]byte
		position := 0
		prefix := fmt.bprintf(line[position:], "%08X  ", offset)
		position += len(prefix)
		for column in 0 ..< HEX_BYTES_PER_ROW {
			if offset + column < len(app.viewer_data) {
				part := fmt.bprintf(line[position:], "%02X ", app.viewer_data[offset + column])
				position += len(part)
			} else {
				copy(line[position:], "   ")
				position += 3
			}
		}
		line[position] = ' '
		position += 1
		for column in 0 ..< HEX_BYTES_PER_ROW {
			if offset + column >= len(app.viewer_data) do break
			byte := app.viewer_data[offset + column]
			if byte < 32 || byte > 126 do byte = '.'
			line[position] = byte
			position += 1
		}
		tui.buffer_write(buffer, rect.x + 2, rect.y + 1 + row, string(line[:position]), theme.dialog_surface, rect.width - 4)
	}
}
