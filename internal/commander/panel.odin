package commander

import "core:os"
import "core:strings"
import "tc:internal/fsops"

panel_destroy :: proc(panel: ^Panel_State) {
	delete(panel.path)
	if panel.files != nil {
		os.file_info_slice_delete(panel.files, context.allocator)
	}
	panel_clear_marks(panel)
	delete(panel.marked)
	panel^ = {}
}

panel_clear_marks :: proc(panel: ^Panel_State) {
	for name in panel.marked {
		delete(name)
	}
	clear(&panel.marked)
}

panel_load :: proc(panel: ^Panel_State, path: string) -> os.Error {
	absolute_path, files, load_err := fsops.Load_Directory(path, context.allocator)
	if load_err != nil {
		return load_err
	}

	delete(panel.path)
	if panel.files != nil {
		os.file_info_slice_delete(panel.files, context.allocator)
	}
	panel_clear_marks(panel)
	panel.path = absolute_path
	panel.files = files
	panel.selected = 0
	panel.offset = 0
	return nil
}

panel_refresh :: proc(panel: ^Panel_State) -> os.Error {
	path_copy := strings.clone(panel.path) or_return
	defer delete(path_copy)
	return panel_load(panel, path_copy)
}

panel_item_count :: proc(panel: ^Panel_State) -> int {
	return len(panel.files) + 1 // Wirtualny wpis "..".
}

panel_move_selection :: proc(panel: ^Panel_State, delta: int) {
	last := max(panel_item_count(panel) - 1, 0)
	panel.selected = clamp(panel.selected + delta, 0, last)
}

panel_is_marked :: proc(panel: ^Panel_State, name: string) -> bool {
	for marked_name in panel.marked {
		if marked_name == name {
			return true
		}
	}
	return false
}

panel_toggle_mark :: proc(panel: ^Panel_State) {
	if panel.selected == 0 || panel.selected > len(panel.files) {
		return
	}
	name := panel.files[panel.selected - 1].name
	for marked_index in 0 ..< len(panel.marked) {
		if panel.marked[marked_index] == name {
			delete(panel.marked[marked_index])
			ordered_remove(&panel.marked, marked_index)
			panel_move_selection(panel, 1)
			return
		}
	}
	cloned_name := strings.clone(name) or_else ""
	if len(cloned_name) == 0 {
		return
	}
	append(&panel.marked, cloned_name)
	panel_move_selection(panel, 1)
}

panel_operation_entries :: proc(panel: ^Panel_State) -> [dynamic]os.File_Info {
	entries := make([dynamic]os.File_Info, 0, max(len(panel.marked), 1))
	if len(panel.marked) > 0 {
		for file in panel.files {
			if panel_is_marked(panel, file.name) {
				append(&entries, file)
			}
		}
	} else if panel.selected > 0 && panel.selected <= len(panel.files) {
		append(&entries, panel.files[panel.selected - 1])
	}
	return entries
}
