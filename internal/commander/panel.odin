package commander

import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:unicode/utf8"
import "tc:internal/fsops"

panel_destroy :: proc(panel: ^Panel_State) {
	if len(panel.archive_root) > 0 do os.remove_all(filepath.dir(panel.archive_root))
	delete(panel.path)
	delete(panel.remote_return_path)
	for path in panel.tree_paths do delete(path)
	delete(panel.tree_paths)
	delete(panel.preview_path)
	delete(panel.preview_data)
	if panel.files != nil {
		os.file_info_slice_delete(panel.files, context.allocator)
	}
	panel_clear_marks(panel)
	delete(panel.marked)
	delete(panel.filter)
	delete(panel.quick_search)
	delete(panel.archive_root)
	delete(panel.archive_source)
	delete(panel.archive_parent)
	for path in panel.history do delete(path)
	delete(panel.history)
	panel^ = {}
}

panel_clear_marks :: proc(panel: ^Panel_State) {
	for name in panel.marked {
		delete(name)
	}
	clear(&panel.marked)
}

panel_load :: proc(panel: ^Panel_State, path: string, record_history := true) -> os.Error {
	options := fsops.Directory_Options {
		show_hidden = panel.show_hidden,
		filter = panel.filter,
		sort_kind = panel.sort_kind,
		reverse = panel.sort_reverse,
	}
	absolute_path: string
	files: []os.File_Info
	load_err: os.Error
	if remote_path_valid(path) {
		absolute_path, files, load_err = remote_load_directory(path, options)
	} else {
		absolute_path, files, load_err = fsops.Load_Directory(path, context.allocator, options)
	}
	if load_err != nil {
		return load_err
	}
	same_path := panel.path == absolute_path
	selected_name: string
	if same_path && panel.selected > 0 && panel.selected <= len(panel.files) {
		selected_name = strings.clone(panel.files[panel.selected - 1].name) or_else ""
	}
	defer delete(selected_name)

	delete(panel.path)
	if panel.files != nil {
		os.file_info_slice_delete(panel.files, context.allocator)
	}
	if !same_path do panel_clear_marks(panel)
	panel.path = absolute_path
	panel.remote = remote_path_valid(absolute_path)
	panel.files = files
	update_panel_space(panel)
	panel.selected = 0
	panel.offset = 0
	if same_path {
		panel_prune_marks(panel)
		panel_select_name(panel, selected_name)
	}
	if record_history && !same_path {
		panel_record_history(panel, panel.path)
	}
	if panel.mode == .Tree do panel_tree_refresh(panel)
	return nil
}

panel_refresh :: proc(panel: ^Panel_State) -> os.Error {
	path_copy := strings.clone(panel.path) or_return
	defer delete(path_copy)
	return panel_load(panel, path_copy, false)
}

panel_record_history :: proc(panel: ^Panel_State, path: string) {
	if len(panel.history) > 0 && panel.history_index >= 0 && panel.history[panel.history_index] == path {
		return
	}
	for len(panel.history) > panel.history_index + 1 {
		delete(panel.history[len(panel.history) - 1])
		ordered_remove(&panel.history, len(panel.history) - 1)
	}
	append(&panel.history, strings.clone(path) or_else "")
	panel.history_index = len(panel.history) - 1
}

panel_history_move :: proc(panel: ^Panel_State, delta: int) -> os.Error {
	target := panel.history_index + delta
	if target < 0 || target >= len(panel.history) do return nil
	path := panel.history[target]
	err := panel_load(panel, path, false)
	if err == nil do panel.history_index = target
	return err
}

panel_prune_marks :: proc(panel: ^Panel_State) {
	index := 0
	for index < len(panel.marked) {
		found := false
		for file in panel.files {
			if file.name == panel.marked[index] {
				found = true
				break
			}
		}
		if found {
			index += 1
		} else {
			delete(panel.marked[index])
			ordered_remove(&panel.marked, index)
		}
	}
}

panel_item_count :: proc(panel: ^Panel_State) -> int {
	return len(panel.files) + 1 // Wirtualny wpis "..".
}

panel_move_selection :: proc(panel: ^Panel_State, delta: int) {
	last := max(panel_item_count(panel) - 1, 0)
	panel.selected = clamp(panel.selected + delta, 0, last)
}

panel_move_page :: proc(panel: ^Panel_State, delta, page_size: int) {
	panel_move_selection(panel, delta * max(page_size, 1))
}

panel_select_edge :: proc(panel: ^Panel_State, last: bool) {
	panel.selected = 0
	if last do panel.selected = max(panel_item_count(panel) - 1, 0)
}

panel_quick_search :: proc(panel: ^Panel_State, character: rune) -> bool {
	encoded_bytes, encoded_width := utf8.encode_rune(character)
	encoded := string(encoded_bytes[:encoded_width])
	new_search := strings.concatenate({panel.quick_search, encoded})
	delete(panel.quick_search)
	panel.quick_search = new_search
	needle := strings.to_lower(panel.quick_search, context.temp_allocator) or_else panel.quick_search
	for file, index in panel.files {
		name := strings.to_lower(file.name, context.temp_allocator) or_else file.name
		if strings.has_prefix(name, needle) {
			panel.selected = index + 1
			return true
		}
	}
	return false
}

panel_quick_search_backspace :: proc(panel: ^Panel_State) -> bool {
	if len(panel.quick_search) == 0 do return false
	delete(panel.quick_search)
	panel.quick_search = ""
	return true
}

panel_mark_pattern :: proc(panel: ^Panel_State, pattern: string, select_entries: bool) -> bool {
	matched := false
	for file in panel.files {
		matches, err := filepath.match(pattern, file.name)
		if err != nil || !matches do continue
		matched = true
		marked := panel_is_marked(panel, file.name)
		if select_entries && !marked {
			append(&panel.marked, strings.clone(file.name) or_else "")
		} else if !select_entries && marked {
			for name, index in panel.marked {
				if name == file.name {
					delete(panel.marked[index])
					ordered_remove(&panel.marked, index)
					break
				}
			}
		}
	}
	return matched
}

panel_invert_marks :: proc(panel: ^Panel_State) {
	for file in panel.files {
		found := -1
		for name, index in panel.marked {
			if name == file.name {
				found = index
				break
			}
		}
		if found >= 0 {
			delete(panel.marked[found])
			ordered_remove(&panel.marked, found)
		} else {
			append(&panel.marked, strings.clone(file.name) or_else "")
		}
	}
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
