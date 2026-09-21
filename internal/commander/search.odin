package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:internal/tui"

MAX_SEARCH_RESULTS :: 5000
MAX_CONTENT_SEARCH_SIZE :: 8 * 1024 * 1024

begin_search :: proc(app: ^App_State) {
	clear_edit_name(&app.search_query, &app.search_query_cursor)
	app.search_edit_pending = true
}

handle_search_edit_event :: proc(app: ^App_State, event: tui.Event) {
	if event.kind == .Key && event.key == .Tab {
		app.search_contents = !app.search_contents
		return
	}
	switch handle_name_edit_input(&app.search_query, &app.search_query_cursor, event, true) {
	case .Cancel:
		app.search_edit_pending = false
		set_status(app, strings.clone(tr("Anulowano wyszukiwanie")) or_else "")
	case .Submit:
		if len(strings.trim_space(app.search_query)) == 0 {
			set_status(app, strings.clone(tr("Podaj szukany tekst")) or_else "")
			return
		}
		app.search_edit_pending = false
		run_search(app)
	case .None:
	}
}

clear_search_results :: proc(app: ^App_State) {
	for path in app.search_results do delete(path)
	clear(&app.search_results)
	delete(app.search_root)
	app.search_root = ""
	app.search_selected = 0
}

run_search :: proc(app: ^App_State) {
	clear_search_results(app)
	panel := &app.panels[app.active_panel]
	app.search_root = strings.clone(panel.path) or_else ""
	needle := strings.to_lower(strings.trim_space(app.search_query), context.temp_allocator) or_else app.search_query
	walker := os.walker_create(panel.path)
	defer os.walker_destroy(&walker)
	for info in os.walker_walk(&walker) {
		if len(info.fullpath) == 0 {
			continue
		}
		if !panel.show_hidden && len(info.name) > 0 && info.name[0] == '.' {
			if info.type == .Directory do os.walker_skip_dir(&walker)
			continue
		}
		matched := false
		if app.search_contents {
			matched = info.type == .Regular && info.size <= MAX_CONTENT_SEARCH_SIZE && file_contains_text(info.fullpath, needle)
		} else {
			name := strings.to_lower(info.name, context.temp_allocator) or_else info.name
			matched = strings.contains(name, needle)
		}
		if matched {
			append(&app.search_results, strings.clone(info.fullpath) or_else "")
		}
		if len(app.search_results) >= MAX_SEARCH_RESULTS do break
	}
	app.search_results_pending = true
	if len(app.search_results) == 0 {
		set_status(app, fmt.aprintf(tr("Brak wyników dla: %s"), app.search_query))
	} else if len(app.search_results) >= MAX_SEARCH_RESULTS {
		set_status(app, fmt.aprintf(tr("Znaleziono co najmniej %d wyników (limit)"), len(app.search_results)))
	} else {
		set_status(app, fmt.aprintf(tr("Znaleziono %d wyników"), len(app.search_results)))
	}
}

file_contains_text :: proc(path, needle: string) -> bool {
	data, err := os.read_entire_file(path, context.temp_allocator)
	if err != nil do return false
	for byte in data {
		if byte == 0 do return false
	}
	contents := strings.to_lower(string(data), context.temp_allocator) or_else string(data)
	return strings.contains(contents, needle)
}

handle_search_results_event :: proc(app: ^App_State, event: tui.Event) {
	if event.kind != .Key do return
	#partial switch event.key {
	case .Escape:
		app.search_results_pending = false
	case .Up:
		app.search_selected = max(app.search_selected - 1, 0)
	case .Down:
		app.search_selected = min(app.search_selected + 1, max(len(app.search_results) - 1, 0))
	case .Home:
		app.search_selected = 0
	case .End:
		app.search_selected = max(len(app.search_results) - 1, 0)
	case .Enter:
		open_search_result(app)
	case:
	}
}

open_search_result :: proc(app: ^App_State) {
	if app.search_selected < 0 || app.search_selected >= len(app.search_results) do return
	path := app.search_results[app.search_selected]
	info, err := os.stat(path, context.allocator)
	if err != nil {
		set_status(app, fmt.aprintf(tr("Nie można otworzyć wyniku: %s"), os.error_string(err)))
		return
	}
	defer os.file_info_delete(info, context.allocator)
	panel := &app.panels[app.active_panel]
	if info.type == .Directory {
		err = panel_load(panel, path)
	} else {
		directory := filepath.dir(path)
		name := filepath.base(path)
		err = panel_load(panel, directory)
		if err == nil do panel_select_name(panel, name)
	}
	if err != nil {
		set_status(app, fmt.aprintf(tr("Nie można otworzyć wyniku: %s"), os.error_string(err)))
		return
	}
	app.search_results_pending = false
	set_status(app, fmt.aprintf(tr("Wynik wyszukiwania: %s"), path))
}
