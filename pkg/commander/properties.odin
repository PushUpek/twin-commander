package commander

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sys/posix"
import "core:time"
import "tc:pkg/tui"

begin_properties :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	if panel.selected <= 0 || panel.selected > len(panel.files) {
		set_status(app, strings.clone(tr("Wybierz plik lub katalog")) or_else "")
		return
	}
	file := panel.files[panel.selected - 1]
	info, err := os.lstat(file.fullpath, context.allocator)
	if err != nil {
		set_status(app, fmt.aprintf(tr("Nie można odczytać właściwości: %s"), os.error_string(err)))
		return
	}
	defer os.file_info_delete(info, context.allocator)
	clear_property(app)
	app.property_path = strings.clone(info.fullpath) or_else ""
	app.property_name = strings.clone(info.name) or_else ""
	app.property_kind = strings.clone(file_kind_label(info.type)) or_else ""
	app.property_size = info.size
	app.property_is_symlink = info.type == .Symlink
	if modified, ok := time.time_to_rfc3339(info.modification_time, 0, false); ok {
		app.property_modified = modified
	} else {
		app.property_modified = strings.clone("-") or_else ""
	}
	if accessed, ok := time.time_to_rfc3339(info.access_time, 0, false); ok {
		app.property_accessed = accessed
	} else {
		app.property_accessed = strings.clone("-") or_else ""
	}
	if created, ok := time.time_to_rfc3339(info.creation_time, 0, false); ok {
		app.property_created = created
	} else {
		app.property_created = strings.clone("-") or_else ""
	}
	load_property_identity(app, info.fullpath)
	app.property_mode = fmt.aprintf("%03o", transmute(u32)info.mode & 0o777)
	app.property_mode_cursor = len(app.property_mode)
	app.properties_pending = true
}

load_property_identity :: proc(app: ^App_State, path: string) {
	c_path := strings.clone_to_cstring(path, context.temp_allocator) or_else nil
	if c_path == nil do return
	stat: posix.stat_t
	if posix.lstat(c_path, &stat) != nil do return
	if user := posix.getpwuid(stat.st_uid); user != nil {
		app.property_owner = strings.clone(string(user.pw_name)) or_else ""
	} else {
		app.property_owner = fmt.aprintf("%d", stat.st_uid)
	}
	if group := posix.getgrgid(stat.st_gid); group != nil {
		app.property_group = strings.clone(string(group.gr_name)) or_else ""
	} else {
		app.property_group = fmt.aprintf("%d", stat.st_gid)
	}
}

clear_property :: proc(app: ^App_State) {
	delete(app.property_path)
	delete(app.property_name)
	delete(app.property_kind)
	delete(app.property_modified)
	delete(app.property_accessed)
	delete(app.property_created)
	delete(app.property_mode)
	delete(app.property_owner)
	delete(app.property_group)
	app.property_path = ""
	app.property_name = ""
	app.property_kind = ""
	app.property_modified = ""
	app.property_accessed = ""
	app.property_created = ""
	app.property_mode = ""
	app.property_owner = ""
	app.property_group = ""
	app.property_mode_cursor = 0
	app.property_size = 0
	app.property_is_symlink = false
}

file_kind_label :: proc(kind: os.File_Type) -> string {
	switch kind {
	case .Directory: return tr("katalog")
	case .Regular: return tr("plik")
	case .Symlink: return tr("link symboliczny")
	case .Named_Pipe: return tr("potok nazwany")
	case .Socket: return tr("gniazdo")
	case .Block_Device: return tr("urządzenie blokowe")
	case .Character_Device: return tr("urządzenie znakowe")
	case .Undetermined: return tr("nieznany")
	}
	return tr("nieznany")
}

handle_properties_event :: proc(app: ^App_State, event: tui.Event) {
	if app.property_is_symlink {
		if event.kind == .Key && (event.key == .Escape || event.key == .Enter) {
			app.properties_pending = false
		}
		return
	}
	switch handle_name_edit_input(&app.property_mode, &app.property_mode_cursor, event) {
	case .Cancel:
		app.properties_pending = false
	case .Submit:
		value, ok := parse_octal_mode(app.property_mode)
		if !ok {
			set_status(app, strings.clone(tr("Uprawnienia muszą mieć postać 000-777")) or_else "")
			return
		}
		if err := os.chmod(app.property_path, os.perm(value)); err != nil {
			set_status(app, fmt.aprintf(tr("Nie można zmienić uprawnień: %s"), os.error_string(err)))
			return
		}
		app.properties_pending = false
		panel_refresh(&app.panels[app.active_panel])
		set_status(app, fmt.aprintf(tr("Zmieniono uprawnienia %s na %s"), app.property_name, app.property_mode))
	case .None:
	}
}

parse_octal_mode :: proc(value: string) -> (int, bool) {
	if len(value) != 3 do return 0, false
	for character in value {
		if character < '0' || character > '7' do return 0, false
	}
	parsed, ok := strconv.parse_int(value, 8)
	return parsed, ok
}
