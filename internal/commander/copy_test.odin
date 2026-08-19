package commander

import "core:os"
import "core:path/filepath"
import "core:testing"
import "tc:internal/tui"

@(test)
existing_destination_requires_confirmation_before_overwrite :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp(
		"",
		"twin-commander-confirm-*",
		context.allocator,
	)
	if !testing.expectf(
		t,
		temp_err == nil,
		"cannot create temp directory: %s",
		os.error_string(temp_err),
	) {
		return
	}
	defer delete(temp_path)
	defer os.remove_all(temp_path)

	source_dir := filepath.join({temp_path, "source"}) or_else ""
	defer delete(source_dir)
	destination_dir := filepath.join({temp_path, "destination"}) or_else ""
	defer delete(destination_dir)
	testing.expect(t, os.make_directory(source_dir) == nil)
	testing.expect(t, os.make_directory(destination_dir) == nil)

	source_path := filepath.join({source_dir, "raport.txt"}) or_else ""
	defer delete(source_path)
	destination_path := filepath.join({destination_dir, "raport.txt"}) or_else ""
	defer delete(destination_path)
	testing.expect(t, os.write_entire_file_from_string(source_path, "nowa treść") == nil)
	testing.expect(t, os.write_entire_file_from_string(destination_path, "stara treść") == nil)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], source_dir) == nil)
	testing.expect(t, panel_load(&app.panels[1], destination_dir) == nil)
	app.panels[0].selected = 1

	copy_selected_file(nil, &app)
	testing.expect(t, app.overwrite_pending)
	handle_overwrite_event(nil, &app, tui.Event{kind = .Key, key = .Escape})
	testing.expect(t, !app.overwrite_pending)
	expect_file_content(t, destination_path, "stara treść")

	copy_selected_file(nil, &app)
	testing.expect(t, app.overwrite_pending)
	handle_overwrite_event(nil, &app, tui.Event{kind = .Text, text = 'W'})
	testing.expect(t, !app.overwrite_pending)
	expect_file_content(t, destination_path, "nowa treść")
}

@(test)
selected_directory_is_copied_recursively :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp(
		"",
		"twin-commander-copy-ui-dir-*",
		context.allocator,
	)
	if !testing.expectf(
		t,
		temp_err == nil,
		"cannot create temp directory: %s",
		os.error_string(temp_err),
	) {
		return
	}
	defer delete(temp_path)
	defer os.remove_all(temp_path)

	source_panel_path := filepath.join({temp_path, "source"}) or_else ""
	defer delete(source_panel_path)
	destination_panel_path := filepath.join({temp_path, "destination"}) or_else ""
	defer delete(destination_panel_path)
	source_directory := filepath.join({source_panel_path, "documents"}) or_else ""
	defer delete(source_directory)
	source_file := filepath.join({source_directory, "note.txt"}) or_else ""
	defer delete(source_file)
	destination_file := filepath.join({destination_panel_path, "documents", "note.txt"}) or_else ""
	defer delete(destination_file)
	testing.expect(t, os.make_directory(source_panel_path) == nil)
	testing.expect(t, os.make_directory(destination_panel_path) == nil)
	testing.expect(t, os.make_directory(source_directory) == nil)
	testing.expect(t, os.write_entire_file_from_string(source_file, "folder content") == nil)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], source_panel_path) == nil)
	testing.expect(t, panel_load(&app.panels[1], destination_panel_path) == nil)
	app.panels[0].selected = 1
	copy_selected_file(nil, &app)
	expect_file_content(t, destination_file, "folder content")
}

expect_file_content :: proc(t: ^testing.T, path, expected: string) {
	content, read_err := os.read_entire_file(path, context.allocator)
	defer delete(content)
	if testing.expectf(t, read_err == nil, "cannot read %s: %s", path, os.error_string(read_err)) {
		testing.expect_value(t, string(content), expected)
	}
}
