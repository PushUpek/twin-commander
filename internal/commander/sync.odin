package commander

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import "tc:internal/fsops"
import "tc:internal/tui"

Sync_Entry :: struct {
	path: string,
	size: i64,
	type: os.File_Type,
	modified: i64,
}

sync_entries_destroy :: proc(entries: ^[dynamic]Sync_Entry) {
	for entry in entries^ do delete(entry.path)
	delete(entries^)
	entries^ = nil
}

sync_snapshot :: proc(panel: ^Panel_State) -> ([dynamic]Sync_Entry, bool) {
	entries: [dynamic]Sync_Entry
	if panel.remote {
		output, ok := remote_run([]string{"lsjson", "--recursive", "--no-mimetype", panel.path})
		if !ok do return entries, false
		defer delete(output)
		parsed, err := json.parse(output, parse_integers = true)
		if err != nil do return entries, false
		defer json.destroy_value(parsed)
		items, valid := parsed.(json.Array)
		if !valid do return entries, false
		for item in items {
			object, object_ok := item.(json.Object)
			if !object_ok do continue
			path_value, has_path := object["Path"]
			if !has_path do continue
			path_text, path_ok := path_value.(json.String)
			if !path_ok || !sync_relative_path_valid(string(path_text)) do continue
			entry := Sync_Entry{path = strings.clone(string(path_text)) or_else "", type = .Regular}
			if value, exists := object["IsDir"]; exists {
				if directory, is_bool := value.(json.Boolean); is_bool && bool(directory) do entry.type = .Directory
			}
			if value, exists := object["Size"]; exists {
				if size, is_int := value.(json.Integer); is_int do entry.size = i64(size)
			}
			if value, exists := object["ModTime"]; exists {
				if text, is_string := value.(json.String); is_string {
					moment, consumed := time.rfc3339_to_time_utc(string(text))
					if consumed == len(string(text)) do entry.modified = time.time_to_unix_nano(moment)
				}
			}
			append(&entries, entry)
		}
		return entries, true
	}
	walker := os.walker_create(panel.path)
	defer os.walker_destroy(&walker)
	for info in os.walker_walk(&walker) {
		if len(info.fullpath) == 0 do continue
		relative, err := filepath.rel(panel.path, info.fullpath)
		if err != nil do continue
		if relative == "." {
			delete(relative)
			continue
		}
		append(&entries, Sync_Entry{
			path = relative,
			size = info.size,
			type = info.type,
			modified = time.time_to_unix_nano(info.modification_time),
		})
	}
	return entries, true
}

sync_relative_path_valid :: proc(path: string) -> bool {
	if len(path) == 0 || path == "." || strings.has_prefix(path, "/") do return false
	remaining := path
	for component in strings.split_iterator(&remaining, "/") {
		if component == "" || component == "." || component == ".." do return false
	}
	return true
}

sync_find :: proc(entries: []Sync_Entry, path: string) -> (Sync_Entry, bool) {
	for entry in entries {
		if entry.path == path do return entry, true
	}
	return {}, false
}

sync_differs :: proc(left, right: Sync_Entry) -> bool {
	if left.type != right.type || left.size != right.size do return true
	if left.type == .Directory do return false
	return left.modified != 0 && right.modified != 0 && left.modified != right.modified
}

sync_mark_top :: proc(panel: ^Panel_State, relative: string) {
	name := relative
	if slash := strings.index_byte(relative, '/'); slash >= 0 do name = relative[:slash]
	if _, found := find_entry(panel.files, name); found do panel_mark_name(panel, name)
}

compare_recursive :: proc(app: ^App_State) {
	left, left_ok := sync_snapshot(&app.panels[0])
	defer sync_entries_destroy(&left)
	right, right_ok := sync_snapshot(&app.panels[1])
	defer sync_entries_destroy(&right)
	if !left_ok || !right_ok {
		set_status(app, strings.clone(tr("Nie można porównać katalogów rekurencyjnie")) or_else "")
		return
	}
	panel_clear_marks(&app.panels[0])
	panel_clear_marks(&app.panels[1])
	differences := 0
	for entry in left {
		other, found := sync_find(right[:], entry.path)
		if !found || sync_differs(entry, other) {
			differences += 1
			sync_mark_top(&app.panels[0], entry.path)
			sync_mark_top(&app.panels[1], entry.path)
		}
	}
	for entry in right {
		if _, found := sync_find(left[:], entry.path); !found {
			differences += 1
			sync_mark_top(&app.panels[0], entry.path)
			sync_mark_top(&app.panels[1], entry.path)
		}
	}
	set_status(app, fmt.aprintf(tr("Rekurencyjnie: %d różnic; oznaczono katalogi nadrzędne"), differences))
}

begin_sync :: proc(app: ^App_State) {
	source := &app.panels[app.active_panel]
	destination := &app.panels[1 - app.active_panel]
	if panel_is_archive(destination) {
		archive_read_only_status(app)
		return
	}
	if source.path == destination.path || path_is_inside(destination.path, source.path) {
		set_status(app, strings.clone(tr("Katalog docelowy nie może być źródłem ani jego podkatalogiem")) or_else "")
		return
	}
	left, left_ok := sync_snapshot(source)
	defer sync_entries_destroy(&left)
	right, right_ok := sync_snapshot(destination)
	defer sync_entries_destroy(&right)
	if !left_ok || !right_ok {
		set_status(app, strings.clone(tr("Nie można przygotować synchronizacji katalogów")) or_else "")
		return
	}
	app.sync_new_count = 0
	app.sync_changed_count = 0
	app.sync_extra_count = 0
	for entry in left {
		other, found := sync_find(right[:], entry.path)
		if !found do app.sync_new_count += 1
		else if sync_differs(entry, other) do app.sync_changed_count += 1
	}
	for entry in right {
		if _, found := sync_find(left[:], entry.path); !found do app.sync_extra_count += 1
	}
	app.sync_pending = true
}

handle_sync_event :: proc(app: ^App_State, event: tui.Event) {
	choice := confirmation_choice(event)
	if choice == .None do return
	app.sync_pending = false
	if choice == .No do return
	sync_execute(app)
}

sync_execute :: proc(app: ^App_State) {
	source := &app.panels[app.active_panel]
	destination := &app.panels[1 - app.active_panel]
	if source.remote || destination.remote {
		output, ok := remote_run([]string{"copy", "--create-empty-src-dirs", source.path, destination.path})
		delete(output)
		if !ok {
			set_status(app, strings.clone(tr("Synchronizacja zdalna nie powiodła się")) or_else "")
			return
		}
	} else {
		entries, ok := sync_snapshot(source)
		defer sync_entries_destroy(&entries)
		if !ok do return
		for entry in entries {
			source_path := filepath.join({source.path, entry.path}) or_else ""
			dest_path := filepath.join({destination.path, entry.path}) or_else ""
			if entry.type == .Directory {
				if err := os.make_directory_all(dest_path); err != nil && err != .Exist {
					delete(source_path)
					delete(dest_path)
					set_status(app, fmt.aprintf(tr("Błąd synchronizacji: %s"), os.error_string(err)))
					return
				}
			} else if entry.type == .Regular || entry.type == .Symlink {
				parent := filepath.dir(dest_path)
				os.make_directory_all(parent)
				if err := fsops.Copy_Entry(source_path, dest_path, true); err != nil {
					delete(source_path)
					delete(dest_path)
					set_status(app, fmt.aprintf(tr("Błąd synchronizacji: %s"), os.error_string(err)))
					return
				}
			}
			delete(source_path)
			delete(dest_path)
		}
	}
	panel_refresh(source)
	panel_refresh(destination)
	set_status(app, strings.clone(tr("Synchronizacja zakończona; dodatkowe pliki w celu zachowano")) or_else "")
}

draw_sync_dialog :: proc(buffer: ^tui.Buffer, width, height: int, app: ^App_State, theme: Theme) {
	dialog := dialog_open(buffer, width, height, 10, tr("Synchronizacja jednokierunkowa"), theme)
	direction := fmt.aprintf("%s  →  %s", app.panels[app.active_panel].path, app.panels[1 - app.active_panel].path)
	defer delete(direction)
	dialog_write(dialog, 1, direction, .Accent)
	counts := fmt.aprintf(tr("Nowe: %d  Zmienione: %d"), app.sync_new_count, app.sync_changed_count)
	defer delete(counts)
	dialog_write(dialog, 3, counts)
	extra := fmt.aprintf(tr("Dodatkowe w celu: %d (pozostaną)"), app.sync_extra_count)
	defer delete(extra)
	dialog_write(dialog, 4, extra)
	dialog_write(dialog, 6, tr("Kopiowanie do drugiego panelu; bez usuwania plików"))
	dialog_write(dialog, 8, tr(" Enter/T Start   Esc/N Anuluj "), .Action)
}
