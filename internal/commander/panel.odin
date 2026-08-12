package commander

import "core:os"
import "core:strings"
import "tc:internal/fsops"

panel_destroy :: proc(panel: ^Panel_State) {
	delete(panel.path)
	if panel.files != nil {
		os.file_info_slice_delete(panel.files, context.allocator)
	}
	panel^ = {}
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
