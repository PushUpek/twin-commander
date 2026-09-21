package commander

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

compare_panels :: proc(app: ^App_State) {
	left := &app.panels[0]
	right := &app.panels[1]
	panel_clear_marks(left)
	panel_clear_marks(right)
	for file in left.files {
		other, found := find_entry(right.files, file.name)
		if !found || entries_differ(file, other) do panel_mark_name(left, file.name)
	}
	for file in right.files {
		other, found := find_entry(left.files, file.name)
		if !found || entries_differ(file, other) do panel_mark_name(right, file.name)
	}
	count := len(left.marked) + len(right.marked)
	if count == 0 {
		set_status(app, strings.clone(tr("Panele mają taką samą zawartość")) or_else "")
	} else {
		set_status(app, fmt.aprintf(tr("Oznaczono %d różniących się elementów"), count))
	}
}

find_entry :: proc(files: []os.File_Info, name: string) -> (os.File_Info, bool) {
	for file in files {
		if file.name == name do return file, true
	}
	return {}, false
}

entries_differ :: proc(left, right: os.File_Info) -> bool {
	if left.type != right.type do return true
	if left.type == .Directory do return false
	return left.size != right.size ||
		time.time_to_unix_nano(left.modification_time) != time.time_to_unix_nano(right.modification_time)
}

panel_mark_name :: proc(panel: ^Panel_State, name: string) {
	if panel_is_marked(panel, name) do return
	append(&panel.marked, strings.clone(name) or_else "")
}
