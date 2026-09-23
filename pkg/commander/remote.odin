package commander

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import "tc:pkg/fsops"
import "tc:pkg/tui"

// Remote paths use an rclone-configured remote (for example server:photos).
// Arguments are passed directly to the process, never through a shell.
remote_path_valid :: proc(path: string) -> bool {
	colon := strings.index_byte(path, ':')
	if colon < 1 do return false
	for ch in path[:colon] {
		valid := ch >= 'a' && ch <= 'z' || ch >= 'A' && ch <= 'Z' ||
			ch >= '0' && ch <= '9' || ch == '_' || ch == '-'
		if !valid do return false
	}
	return true
}

remote_join :: proc(directory, name: string) -> string {
	if len(directory) == 0 do return ""
	if directory[len(directory) - 1] == ':' || directory[len(directory) - 1] == '/' {
		return fmt.aprintf("%s%s", directory, name)
	}
	return fmt.aprintf("%s/%s", directory, name)
}

remote_basename :: proc(path: string) -> string {
	if !remote_path_valid(path) do return filepath.base(path)
	start := strings.index_byte(path, ':')
	for ch, index in path {
		if ch == '/' do start = index
	}
	return path[start + 1:]
}

remote_parent :: proc(path: string) -> string {
	colon := strings.index_byte(path, ':')
	if colon < 1 do return ""
	if path[colon + 1:] == "/" || len(path) == colon + 1 do return strings.clone(path) or_else ""
	last := -1
	for ch, index in path {
		if ch == '/' do last = index
	}
	if last == colon + 1 do return strings.clone(path[:colon + 2]) or_else ""
	if last < colon + 1 do return strings.clone(path[:colon + 1]) or_else ""
	return strings.clone(path[:last]) or_else ""
}

remote_run :: proc(arguments: []string) -> ([]byte, bool) {
	command := make([]string, len(arguments) + 1, context.temp_allocator)
	defer delete(command, context.temp_allocator)
	command[0] = "rclone"
	copy(command[1:], arguments)
	state, output, errors, err := os.process_exec(os.Process_Desc{command = command}, context.allocator)
	defer delete(errors)
	if err != nil || !state.success || state.exit_code != 0 {
		delete(output)
		return nil, false
	}
	return output, true
}

remote_load_directory :: proc(path: string, options: fsops.Directory_Options) -> (string, []os.File_Info, os.Error) {
	if !remote_path_valid(path) do return "", nil, .Invalid_Path
	output, ok := remote_run([]string{"lsjson", "--no-mimetype", path})
	if !ok do return "", nil, .Invalid_Command
	defer delete(output)
	return remote_parse_listing(path, output, options)
}

remote_parse_listing :: proc(path: string, data: []byte, options: fsops.Directory_Options) -> (string, []os.File_Info, os.Error) {
	parsed, err := json.parse(data, parse_integers = true)
	if err != nil do return "", nil, .Invalid_File
	defer json.destroy_value(parsed)
	items, valid := parsed.(json.Array)
	if !valid do return "", nil, .Invalid_File
	selected := make([dynamic]os.File_Info, 0, len(items))
	defer delete(selected)
	for item in items {
		object, object_ok := item.(json.Object)
		if !object_ok do continue
		name_value, found := object["Name"]
		if !found do continue
		name_json, name_ok := name_value.(json.String)
		if !name_ok do continue
		name := string(name_json)
		if !remote_entry_name_valid(name) do continue
		if !options.show_hidden && strings.has_prefix(name, ".") do continue
		if len(options.filter) > 0 {
			lower_name := strings.to_lower(name, context.temp_allocator) or_else name
			lower_filter := strings.to_lower(options.filter, context.temp_allocator) or_else options.filter
			if !strings.contains(lower_name, lower_filter) do continue
		}
		fullpath := remote_join(path, name)
		entry_name := fullpath[len(fullpath) - len(name):]
		file := os.File_Info{fullpath = fullpath, name = entry_name, type = .Regular}
		if directory_value, exists := object["IsDir"]; exists {
			if is_dir, bool_ok := directory_value.(json.Boolean); bool_ok && bool(is_dir) do file.type = .Directory
		}
		if size_value, exists := object["Size"]; exists {
			if size, size_ok := size_value.(json.Integer); size_ok do file.size = i64(size)
		}
		if time_value, exists := object["ModTime"]; exists {
			if time_text, time_ok := time_value.(json.String); time_ok {
				parsed_time, consumed := time.rfc3339_to_time_utc(string(time_text))
				if consumed == len(string(time_text)) do file.modification_time = parsed_time
			}
		}
		append(&selected, file)
	}
	files := make([]os.File_Info, len(selected))
	copy(files, selected[:])
	fsops.sort_files(files, options.sort_kind, options.reverse)
	return strings.clone(path) or_else "", files, nil
}

remote_entry_name_valid :: proc(name: string) -> bool {
	if len(name) == 0 || name == "." || name == ".." do return false
	for ch in name {
		if ch == '/' || ch == '\x00' do return false
	}
	return true
}

begin_remote :: proc(app: ^App_State) {
	version, available := remote_run([]string{"version"})
	delete(version)
	if !available {
		set_status(app, strings.clone(tr("Zainstaluj rclone, aby korzystać z panelu SFTP/FTP")) or_else "")
		return
	}
	delete(app.remote_text)
	app.remote_text = strings.clone("server:") or_else ""
	app.remote_cursor = len(app.remote_text)
	app.remote_edit_pending = true
}

handle_remote_edit_event :: proc(app: ^App_State, event: tui.Event) {
	switch handle_name_edit_input(&app.remote_text, &app.remote_cursor, event, true) {
	case .Cancel:
		app.remote_edit_pending = false
	case .Submit:
		path := strings.trim_space(app.remote_text)
		if !remote_path_valid(path) {
			set_status(app, strings.clone(tr("Podaj skonfigurowany zdalny katalog w formacie nazwa:ścieżka")) or_else "")
			return
		}
		panel := &app.panels[app.active_panel]
		if !panel.remote {
			delete(panel.remote_return_path)
			panel.remote_return_path = strings.clone(panel.path) or_else ""
		}
		if err := panel_load(panel, path); err != nil {
			set_status(app, fmt.aprintf(tr("Nie można otworzyć zdalnego katalogu: %s"), os.error_string(err)))
			return
		}
		app.remote_edit_pending = false
		set_status(app, fmt.aprintf(tr("Katalog: %s"), panel.path))
	case .None:
	}
}

remote_leave :: proc(panel: ^Panel_State) -> bool {
	if !panel.remote do return false
	parent := remote_parent(panel.path)
	defer delete(parent)
	if parent != panel.path {
		return panel_load(panel, parent) == nil
	}
	if len(panel.remote_return_path) == 0 do return false
	return panel_load(panel, panel.remote_return_path) == nil
}

remote_transfer :: proc(source, destination: string, move: bool) -> bool {
	operation := "copyto"
	if move do operation = "moveto"
	output, ok := remote_run([]string{operation, source, destination})
	delete(output)
	return ok
}

remote_create :: proc(path: string, directory: bool) -> bool {
	if directory {
		output, ok := remote_run([]string{"mkdir", path})
		delete(output)
		return ok
	}
	temporary, err := os.make_directory_temp("", "twin-commander-empty-*", context.allocator)
	if err != nil do return false
	defer delete(temporary)
	defer os.remove_all(temporary)
	empty_path := filepath.join({temporary, "empty"}) or_else ""
	defer delete(empty_path)
	if os.write_entire_file_from_string(empty_path, "") != nil do return false
	return remote_transfer(empty_path, path, false)
}

remote_delete :: proc(path: string, directory: bool) -> bool {
	operation := "deletefile"
	if directory do operation = "purge"
	output, ok := remote_run([]string{operation, path})
	delete(output)
	return ok
}

remote_destination :: proc(panel: ^Panel_State, name: string) -> string {
	if panel.remote do return remote_join(panel.path, name)
	return filepath.join({panel.path, name}) or_else ""
}

remote_prepare_transfer :: proc(app: ^App_State, target_name: string, move: bool) {
	source := &app.panels[app.active_panel]
	destination := &app.panels[1 - app.active_panel]
	if panel_is_archive(destination) {
		archive_read_only_status(app)
		return
	}
	entries := panel_operation_entries(source)
	defer delete(entries)
	if len(entries) == 0 {
		set_status(app, strings.clone(tr("Wybierz plik lub katalog")) or_else "")
		return
	}
	full_listing_path: string
	full_listing: []os.File_Info
	defer {
		delete(full_listing_path)
		if full_listing != nil do os.file_info_slice_delete(full_listing, context.allocator)
	}
	if destination.remote {
		list_err: os.Error
		full_listing_path, full_listing, list_err = remote_load_directory(destination.path, fsops.Directory_Options{show_hidden = true})
		if list_err != nil {
			set_status(app, strings.clone(tr("Nie można sprawdzić zawartości katalogu docelowego")) or_else "")
			return
		}
	}
	for file in entries {
		name := file.name
		if len(target_name) > 0 do name = target_name
		target := remote_destination(destination, name)
		if len(target) == 0 || target == file.fullpath ||
			(file.type == .Directory && path_is_inside(target, file.fullpath)) {
			delete(target)
			set_status(app, strings.clone(tr("Źródło i cel są tym samym elementem")) or_else "")
			return
		}
		delete(target)
		exists := false
		if destination.remote {
			_, exists = find_entry(full_listing, name)
		} else {
			local_target := filepath.join({destination.path, name}) or_else ""
			if info, err := os.lstat(local_target, context.temp_allocator); err == nil {
				exists = true
				os.file_info_delete(info, context.temp_allocator)
			} else if err != .Not_Exist {
				delete(local_target)
				set_status(app, strings.clone(tr("Nie można sprawdzić elementu docelowego")) or_else "")
				return
			}
			delete(local_target)
		}
		if exists {
			if move {
				app.move_pending = true
				app.move_edit_pending = false
				app.pending_name = name
			} else {
				app.overwrite_pending = true
				app.copy_edit_pending = false
				app.copy_name = name
			}
			app.pending_count = len(entries)
			return
		}
	}
	if move {
		app.move_edit_pending = false
	} else {
		app.copy_edit_pending = false
	}
	remote_perform_transfer(app, target_name, move)
	if move do clear_move_edit(app)
	else do clear_copy_edit(app)
}

remote_perform_transfer :: proc(app: ^App_State, target_name: string, move: bool) {
	source := &app.panels[app.active_panel]
	destination := &app.panels[1 - app.active_panel]
	entries := panel_operation_entries(source)
	defer delete(entries)
	completed := 0
	for file in entries {
		name := file.name
		if len(target_name) > 0 do name = target_name
		target := remote_destination(destination, name)
		if len(target) == 0 || target == file.fullpath ||
			(file.type == .Directory && path_is_inside(target, file.fullpath)) {
			delete(target)
			set_status(app, strings.clone(tr("Źródło i cel są tym samym elementem")) or_else "")
			return
		}
		ok := remote_transfer(file.fullpath, target, move)
		delete(target)
		if !ok {
			name_copy := strings.clone(file.name) or_else ""
			defer delete(name_copy)
			panel_refresh(source)
			panel_refresh(destination)
			set_status(app, fmt.aprintf(tr("Operacja zdalna nie powiodła się dla %s (%d ukończonych)"), name_copy, completed))
			return
		}
		completed += 1
	}
	panel_clear_marks(source)
	panel_refresh(source)
	panel_refresh(destination)
	if move {
		set_status(app, fmt.aprintf(tr("Przeniesiono %d elementów do %s"), completed, destination.path))
	} else {
		set_status(app, fmt.aprintf(tr("Skopiowano %d elementów do %s"), completed, destination.path))
	}
}

remote_create_entry :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	name := strings.trim_space(app.create_name)
	if !remote_relative_path_valid(name) {
		set_status(app, strings.clone(tr("Nieprawidłowa nazwa zdalnego elementu")) or_else "")
		return
	}
	directory := strings.contains_rune(name, '/')
	if !directory {
		listed_path, listed, list_err := remote_load_directory(panel.path, fsops.Directory_Options{show_hidden = true})
		if list_err != nil {
			set_status(app, strings.clone(tr("Nie można sprawdzić zawartości katalogu docelowego")) or_else "")
			return
		}
		_, exists := find_entry(listed, name)
		os.file_info_slice_delete(listed, context.allocator)
		delete(listed_path)
		if exists {
			set_status(app, fmt.aprintf(tr("Element już istnieje: %s"), name))
			return
		}
	}
	path := remote_join(panel.path, name)
	defer delete(path)
	if !remote_create(path, directory) {
		set_status(app, fmt.aprintf(tr("Nie można utworzyć zdalnego elementu: %s"), name))
		return
	}
	set_status(app, fmt.aprintf(tr("Utworzono: %s"), name))
	clear_create_edit(app)
	panel_refresh(panel)
}

remote_relative_path_valid :: proc(path: string) -> bool {
	if len(path) == 0 || strings.has_prefix(path, "/") || strings.contains_rune(path, '\x00') do return false
	remaining := path
	for component in strings.split_iterator(&remaining, "/") {
		if component == ".." || component == "." do return false
	}
	return true
}

remote_perform_delete :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	entries := panel_operation_entries(panel)
	defer delete(entries)
	completed := 0
	for file in entries {
		if !remote_delete(file.fullpath, file.type == .Directory) {
			name := strings.clone(file.name) or_else ""
			defer delete(name)
			panel_refresh(panel)
			set_status(app, fmt.aprintf(tr("Nie można usunąć zdalnego elementu: %s"), name))
			return
		}
		completed += 1
	}
	panel_clear_marks(panel)
	panel_refresh(panel)
	set_status(app, fmt.aprintf(tr("Usunięto %d elementów"), completed))
}
