package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:internal/tui"

begin_bookmarks :: proc(app: ^App_State) {
	app.bookmarks_pending = true
	app.bookmark_selected = clamp(app.bookmark_selected, 0, max(len(app.bookmarks) - 1, 0))
}

bookmarks_load :: proc(app: ^App_State) {
	path := os.get_env("TWIN_COMMANDER_BOOKMARKS_FILE", context.temp_allocator)
	if len(path) == 0 {
		config_dir, err := os.user_config_dir(context.temp_allocator)
		if err != nil do return
		path = filepath.join({config_dir, "twin-commander", "bookmarks"}, context.temp_allocator) or_else ""
	}
	if len(path) == 0 do return
	bookmarks_load_file(app, path)
}

bookmarks_load_file :: proc(app: ^App_State, path: string) {
	delete(app.bookmarks_file)
	app.bookmarks_file = strings.clone(path) or_else ""
	data, err := os.read_entire_file(path, context.temp_allocator)
	if err != nil do return
	text := string(data)
	for line in strings.split_lines_iterator(&text) {
		trimmed := strings.trim_space(line)
		if len(trimmed) == 0 do continue
		if info, stat_err := os.stat(trimmed, context.temp_allocator); stat_err == nil {
			if info.type == .Directory do append(&app.bookmarks, strings.clone(trimmed) or_else "")
			os.file_info_delete(info, context.temp_allocator)
		}
	}
}

bookmarks_save :: proc(app: ^App_State) -> bool {
	if len(app.bookmarks_file) == 0 do return true
	directory := filepath.dir(app.bookmarks_file)
	if err := os.make_directory_all(directory); err != nil do return false
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	for path in app.bookmarks {
		strings.write_string(&builder, path)
		strings.write_byte(&builder, '\n')
	}
	return os.write_entire_file_from_string(app.bookmarks_file, strings.to_string(builder)) == nil
}

handle_bookmarks_event :: proc(app: ^App_State, event: tui.Event) {
	if event.kind == .Key {
		#partial switch event.key {
		case .Escape:
			app.bookmarks_pending = false
		case .Up:
			app.bookmark_selected = max(app.bookmark_selected - 1, 0)
		case .Down:
			app.bookmark_selected = min(app.bookmark_selected + 1, max(len(app.bookmarks) - 1, 0))
		case .Home:
			app.bookmark_selected = 0
		case .End:
			app.bookmark_selected = max(len(app.bookmarks) - 1, 0)
		case .Enter:
			open_selected_bookmark(app)
		case:
		}
		return
	}
	if event.kind != .Text || event.modifiers != {} do return
	switch event.text {
	case 'a', 'A': add_current_bookmark(app)
	case 'd', 'D': remove_selected_bookmark(app)
	case:
	}
}

add_current_bookmark :: proc(app: ^App_State) -> bool {
	path := app.panels[app.active_panel].path
	for existing in app.bookmarks {
		if existing == path {
			set_status(app, strings.clone(tr("Ten katalog jest już w zakładkach")) or_else "")
			return false
		}
	}
	append(&app.bookmarks, strings.clone(path) or_else "")
	app.bookmark_selected = len(app.bookmarks) - 1
	if !bookmarks_save(app) {
		set_status(app, strings.clone(tr("Nie można zapisać zakładek")) or_else "")
		return true
	}
	set_status(app, fmt.aprintf(tr("Dodano zakładkę: %s"), path))
	return true
}

remove_selected_bookmark :: proc(app: ^App_State) -> bool {
	if app.bookmark_selected < 0 || app.bookmark_selected >= len(app.bookmarks) do return false
	path := app.bookmarks[app.bookmark_selected]
	status := fmt.aprintf(tr("Usunięto zakładkę: %s"), path)
	delete(path)
	ordered_remove(&app.bookmarks, app.bookmark_selected)
	app.bookmark_selected = min(app.bookmark_selected, max(len(app.bookmarks) - 1, 0))
	if !bookmarks_save(app) {
		set_status(app, strings.clone(tr("Nie można zapisać zakładek")) or_else "")
		return true
	}
	set_status(app, status)
	return true
}

open_selected_bookmark :: proc(app: ^App_State) {
	if app.bookmark_selected < 0 || app.bookmark_selected >= len(app.bookmarks) do return
	path := app.bookmarks[app.bookmark_selected]
	panel := &app.panels[app.active_panel]
	if panel_is_archive(panel) && !close_archive(panel) {
		set_status(app, strings.clone(tr("Nie można zamknąć widoku archiwum")) or_else "")
		return
	}
	if err := panel_load(panel, path); err != nil {
		set_status(app, fmt.aprintf(tr("Nie można otworzyć zakładki: %s"), path))
		return
	}
	app.bookmarks_pending = false
	set_status(app, fmt.aprintf(tr("Zakładka: %s"), path))
}
