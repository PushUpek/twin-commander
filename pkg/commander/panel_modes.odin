package commander

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:pkg/tui"

MAX_TREE_ENTRIES :: 500
MAX_QUICK_PREVIEW :: 128 * 1024

panel_mode_cycle :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	switch panel.mode {
	case .Files: panel.mode = .Tree
	case .Tree: panel.mode = .Info
	case .Info: panel.mode = .Quick
	case .Quick: panel.mode = .Files
	}
	if panel.mode == .Tree do panel_tree_refresh(panel)
	set_status(app, fmt.aprintf(tr("Tryb panelu: %s"), panel_mode_name(panel.mode)))
}

panel_mode_name :: proc(mode: Panel_Mode) -> string {
	switch mode {
	case .Files: return tr("Pliki")
	case .Tree: return tr("Drzewo")
	case .Info: return tr("Informacje")
	case .Quick: return tr("Szybki podgląd")
	}
	return ""
}

panel_tree_refresh :: proc(panel: ^Panel_State) {
	for path in panel.tree_paths do delete(path)
	clear(&panel.tree_paths)
	append(&panel.tree_paths, strings.clone("..") or_else "")
	append(&panel.tree_paths, strings.clone(".") or_else "")
	if panel.remote {
		output, ok := remote_run([]string{"lsjson", "--recursive", "--dirs-only", "--no-mimetype", panel.path})
		if ok {
			parsed, err := json.parse(output)
			if err == nil {
				if items, valid := parsed.(json.Array); valid {
					for item in items {
						object, object_ok := item.(json.Object)
						if !object_ok do continue
						value, exists := object["Path"]
						if !exists do continue
						path, is_string := value.(json.String)
						if !is_string || !sync_relative_path_valid(string(path)) do continue
						if !panel.show_hidden && tree_path_hidden(string(path)) do continue
						append(&panel.tree_paths, strings.clone(string(path)) or_else "")
						if len(panel.tree_paths) >= MAX_TREE_ENTRIES do break
					}
				}
				json.destroy_value(parsed)
			}
		}
		delete(output)
	} else {
		walker := os.walker_create(panel.path)
		defer os.walker_destroy(&walker)
		for info in os.walker_walk(&walker) {
			if info.type != .Directory || info.fullpath == panel.path do continue
			if !panel.show_hidden && strings.has_prefix(info.name, ".") {
				os.walker_skip_dir(&walker)
				continue
			}
			relative, err := filepath.rel(panel.path, info.fullpath)
			if err != nil do continue
			if sync_relative_path_valid(relative) {
				append(&panel.tree_paths, relative)
			} else {
				delete(relative)
			}
			if len(panel.tree_paths) >= MAX_TREE_ENTRIES do break
		}
	}
	panel.tree_selected = clamp(panel.tree_selected, 0, max(len(panel.tree_paths) - 1, 0))
	panel.tree_offset = 0
}

tree_path_hidden :: proc(path: string) -> bool {
	remaining := path
	for component in strings.split_iterator(&remaining, "/") {
		if strings.has_prefix(component, ".") do return true
	}
	return false
}

panel_tree_activate :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	if panel.tree_selected >= len(panel.tree_paths) do return
	if panel.tree_selected == 0 {
		if panel.remote {
			remote_leave(panel)
		} else {
			parent := filepath.join({panel.path, ".."}) or_else ""
			defer delete(parent)
			panel_load(panel, parent)
		}
		return
	}
	if panel.tree_selected == 1 do return
	path := panel.tree_paths[panel.tree_selected]
	target := remote_join(panel.path, path) if panel.remote else filepath.join({panel.path, path}) or_else ""
	defer delete(target)
	panel.tree_selected = 1
	if err := panel_load(panel, target); err != nil {
		set_status(app, fmt.aprintf(tr("Nie można wejść do katalogu: %s"), os.error_string(err)))
	}
}

panel_preview_update :: proc(app: ^App_State) {
	for index in 0 ..< len(app.panels) {
		panel := &app.panels[index]
		if panel.mode != .Quick do continue
		source := &app.panels[1 - index]
		if app.active_panel == index do source = panel
		path := ""
		file_size: i64
		if source.selected > 0 && source.selected <= len(source.files) {
			file := source.files[source.selected - 1]
			if file.type == .Regular {
				path = file.fullpath
				file_size = file.size
			}
		}
		if path == panel.preview_path do continue
		delete(panel.preview_path)
		delete(panel.preview_data)
		panel.preview_path = strings.clone(path) or_else ""
		panel.preview_data = nil
		if len(path) == 0 || file_size > MAX_QUICK_PREVIEW do continue
		if source.remote {
			limit := fmt.aprintf("%d", MAX_QUICK_PREVIEW)
			panel.preview_data, _ = remote_run([]string{"cat", "--count", limit, path})
			delete(limit)
		} else {
			panel.preview_data, _ = os.read_entire_file(path, context.allocator)
		}
	}
}

draw_panel_mode :: proc(buffer: ^tui.Buffer, rect: tui.Rect, app: ^App_State, index: int, theme: Theme) {
	panel := &app.panels[index]
	active := app.active_panel == index
	if panel.mode == .Files {
		draw_panel(buffer, rect, panel, active, theme)
		return
	}
	style := theme.panel_border_inactive
	if active do style = theme.panel_border_active
	draw_box(buffer, rect, style)
	title := fmt.aprintf("%s · %s", panel_mode_name(panel.mode), panel.path)
	defer delete(title)
	tui.buffer_write(buffer, rect.x + 2, rect.y, title, style, rect.width - 4)
	if panel.mode == .Tree {
		visible := max(rect.height - 2, 0)
		if panel.tree_selected < panel.tree_offset do panel.tree_offset = panel.tree_selected
		if panel.tree_selected >= panel.tree_offset + visible do panel.tree_offset = panel.tree_selected - visible + 1
		for row in 0 ..< min(visible, len(panel.tree_paths) - panel.tree_offset) {
			item_index := panel.tree_offset + row
			item := panel.tree_paths[item_index]
			row_style := theme.panel_row_inactive
			if active do row_style = theme.panel_row_active
			if item_index == panel.tree_selected {
				row_style = theme.selection_inactive
				if active do row_style = theme.selection_active
			}
			tui.buffer_fill(buffer, tui.Rect{x = rect.x + 1, y = rect.y + 1 + row, width = rect.width - 2, height = 1}, tui.Cell{character = ' ', style = row_style})
			depth := 0
			for ch in item do if ch == '/' do depth += 1
			label := fmt.aprintf("%s▸ %s", strings.repeat("  ", min(depth, 8)), filepath.base(item))
			if item == ".." || item == "." do label = fmt.aprintf("▸ %s", item)
			tui.buffer_write(buffer, rect.x + 2, rect.y + 1 + row, label, row_style, rect.width - 4)
			delete(label)
		}
		return
	}
	source := &app.panels[1 - index]
	if active do source = panel
	if source.selected <= 0 || source.selected > len(source.files) {
		tui.buffer_write(buffer, rect.x + 2, rect.y + 2, tr("Wybierz plik w drugim panelu"), theme.panel_row_inactive, rect.width - 4)
		return
	}
	file := source.files[source.selected - 1]
	if panel.mode == .Info {
		rows := []string{
			fmt.aprintf(tr("Nazwa: %s"), file.name),
			fmt.aprintf(tr("Ścieżka: %s"), file.fullpath),
			fmt.aprintf(tr("Typ: %s"), "katalog" if file.type == .Directory else "plik"),
			fmt.aprintf(tr("Rozmiar: %d bajtów"), file.size),
		}
		defer for row in rows do delete(row)
		for row, row_index in rows {
			if row_index + 2 >= rect.height - 1 do break
			tui.buffer_write(buffer, rect.x + 2, rect.y + 2 + row_index, row, theme.panel_row_inactive, rect.width - 4)
		}
		return
	}
	if len(panel.preview_data) == 0 {
		tui.buffer_write(buffer, rect.x + 2, rect.y + 2, tr("Brak podglądu lub plik jest zbyt duży"), theme.panel_row_inactive, rect.width - 4)
		return
	}
	row := 0
	preview := string(panel.preview_data)
	for line in strings.split_lines_iterator(&preview) {
		if row >= rect.height - 2 do break
		clean := strings.builder_make()
		for ch in line {
			if ch < 32 || ch == 127 do strings.write_rune(&clean, '·')
			else do strings.write_rune(&clean, ch)
		}
		tui.buffer_write(buffer, rect.x + 2, rect.y + 1 + row, strings.to_string(clean), theme.panel_row_inactive, rect.width - 4)
		strings.builder_destroy(&clean)
		row += 1
	}
}
