package commander

import "core:os"
import "core:path/filepath"
import "core:testing"
import "tc:internal/tui"

BULK_TEST_NAMES := [?]string{"a.txt", "b.txt"}

@(test)
space_toggles_mark_and_advances_selection :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp("", "twin-commander-mark-*", context.allocator)
	if !testing.expect(t, temp_err == nil) do return
	defer delete(temp_path)
	defer os.remove_all(temp_path)
	for name in BULK_TEST_NAMES {
		path := filepath.join({temp_path, name}) or_else ""
		testing.expect(t, os.write_entire_file_from_string(path, name) == nil)
		delete(path)
	}

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], temp_path) == nil)
	app.panels[0].selected = 1
	running := true
	handle_event(nil, &app, tui.Event{kind = .Text, text = ' '}, &running)
	testing.expect(t, panel_is_marked(&app.panels[0], "a.txt"))
	testing.expect_value(t, app.panels[0].selected, 2)

	app.panels[0].selected = 1
	handle_event(nil, &app, tui.Event{kind = .Text, text = ' '}, &running)
	testing.expect(t, !panel_is_marked(&app.panels[0], "a.txt"))
	testing.expect_value(t, app.panels[0].selected, 2)
}

@(test)
marked_entries_are_copied_as_one_set :: proc(t: ^testing.T) {
	temp_path, source_dir, destination_dir := bulk_directories(t, "copy")
	if len(temp_path) == 0 do return
	defer delete(temp_path)
	defer delete(source_dir)
	defer delete(destination_dir)
	defer os.remove_all(temp_path)
	write_bulk_files(t, source_dir)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], source_dir) == nil)
	testing.expect(t, panel_load(&app.panels[1], destination_dir) == nil)
	mark_all_files(&app.panels[0])
	copy_selected_file(nil, &app)

	expect_bulk_files(t, destination_dir)
	testing.expect_value(t, len(app.panels[0].marked), 0)
}

@(test)
marked_entries_are_moved_as_one_set :: proc(t: ^testing.T) {
	temp_path, source_dir, destination_dir := bulk_directories(t, "move")
	if len(temp_path) == 0 do return
	defer delete(temp_path)
	defer delete(source_dir)
	defer delete(destination_dir)
	defer os.remove_all(temp_path)
	write_bulk_files(t, source_dir)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], source_dir) == nil)
	testing.expect(t, panel_load(&app.panels[1], destination_dir) == nil)
	mark_all_files(&app.panels[0])
	move_selected_entry(&app)

	expect_bulk_files(t, destination_dir)
	testing.expect_value(t, len(app.panels[0].files), 0)
}

@(test)
marked_entries_are_deleted_after_one_confirmation :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp("", "twin-commander-bulk-delete-*", context.allocator)
	if !testing.expect(t, temp_err == nil) do return
	defer delete(temp_path)
	defer os.remove_all(temp_path)
	write_bulk_files(t, temp_path)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], temp_path) == nil)
	mark_all_files(&app.panels[0])
	delete_selected_entry(&app)
	testing.expect(t, app.delete_pending)
	handle_delete_event(&app, tui.Event{kind = .Key, key = .Enter})
	testing.expect_value(t, len(app.panels[0].files), 0)
}

bulk_directories :: proc(t: ^testing.T, operation: string) -> (string, string, string) {
	_ = operation
	temp_path, temp_err := os.make_directory_temp("", "twin-commander-bulk-*", context.allocator)
	if !testing.expect(t, temp_err == nil) do return "", "", ""
	source_dir := filepath.join({temp_path, "source"}) or_else ""
	destination_dir := filepath.join({temp_path, "destination"}) or_else ""
	if !testing.expect(t, os.make_directory(source_dir) == nil) ||
	   !testing.expect(t, os.make_directory(destination_dir) == nil) {
		delete(source_dir)
		delete(destination_dir)
		os.remove_all(temp_path)
		delete(temp_path)
		return "", "", ""
	}
	return temp_path, source_dir, destination_dir
}

write_bulk_files :: proc(t: ^testing.T, directory: string) {
	for name in BULK_TEST_NAMES {
		path := filepath.join({directory, name}) or_else ""
		testing.expect(t, os.write_entire_file_from_string(path, name) == nil)
		delete(path)
	}
}

mark_all_files :: proc(panel: ^Panel_State) {
	for file_index in 1 ..= len(panel.files) {
		panel.selected = file_index
		panel_toggle_mark(panel)
	}
}

expect_bulk_files :: proc(t: ^testing.T, directory: string) {
	for name in BULK_TEST_NAMES {
		path := filepath.join({directory, name}) or_else ""
		expect_file_content(t, path, name)
		delete(path)
	}
}
