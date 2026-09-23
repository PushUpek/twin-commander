package commander

import "core:os"
import "core:path/filepath"
import "core:testing"
import "tc:pkg/tui"

@(test)
move_and_delete_require_confirmation_when_destructive :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp(
		"",
		"twin-commander-actions-*",
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
	testing.expect(t, os.write_entire_file_from_string(source_path, "new") == nil)
	testing.expect(t, os.write_entire_file_from_string(destination_path, "old") == nil)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], source_dir) == nil)
	testing.expect(t, panel_load(&app.panels[1], destination_dir) == nil)
	app.panels[0].selected = 1

	move_selected_entry(&app)
	testing.expect(t, app.move_edit_pending)
	handle_move_edit_event(&app, tui.Event{kind = .Key, key = .Enter})
	testing.expect(t, app.move_pending)
	handle_move_overwrite_event(&app, tui.Event{kind = .Key, key = .Escape})
	testing.expect(t, !app.move_pending)
	expect_file_content(t, source_path, "new")
	expect_file_content(t, destination_path, "old")

	move_selected_entry(&app)
	handle_move_edit_event(&app, tui.Event{kind = .Key, key = .Enter})
	handle_move_overwrite_event(&app, tui.Event{kind = .Key, key = .Enter})
	testing.expect(t, !app.move_pending)
	_, source_err := os.stat(source_path, context.allocator)
	testing.expectf(t, source_err == .Not_Exist, "source still exists; status: %s", app.status)
	expect_file_content(t, destination_path, "new")

	app.active_panel = 1
	app.panels[1].selected = 1
	delete_selected_entry(&app)
	testing.expect(t, app.delete_pending)
	handle_delete_event(&app, tui.Event{kind = .Key, key = .Enter})
	testing.expect(t, !app.delete_pending)
	_, deleted_err := os.stat(destination_path, context.allocator)
	testing.expectf(
		t,
		deleted_err == .Not_Exist,
		"destination still exists; status: %s",
		app.status,
	)
}

@(test)
move_dialog_can_rename_an_entry_in_the_same_directory :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp("", "twin-commander-rename-*", context.allocator)
	if !testing.expect(t, temp_err == nil) do return
	defer delete(temp_path)
	defer os.remove_all(temp_path)

	source_path := filepath.join({temp_path, "old.txt"}) or_else ""
	defer delete(source_path)
	destination_path := filepath.join({temp_path, "new.txt"}) or_else ""
	defer delete(destination_path)
	testing.expect(t, os.write_entire_file_from_string(source_path, "content") == nil)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], temp_path) == nil)
	testing.expect(t, panel_load(&app.panels[1], temp_path) == nil)
	app.panels[0].selected = 1

	move_selected_entry(&app)
	testing.expect(t, app.move_edit_pending)
	for _ in 0 ..< len("old.txt") {
		handle_move_edit_event(&app, tui.Event{kind = .Key, key = .Backspace})
	}
	for character in "new.txt" {
		handle_move_edit_event(&app, tui.Event{kind = .Text, text = character})
	}
	testing.expect_value(t, app.move_name, "new.txt")
	handle_move_edit_event(&app, tui.Event{kind = .Key, key = .Enter})

	testing.expect(t, !app.move_edit_pending)
	testing.expect(t, !app.move_pending)
	_, source_err := os.stat(source_path, context.allocator)
	testing.expect_value(t, source_err, os.Error(.Not_Exist))
	expect_file_content(t, destination_path, "content")
}

@(test)
delete_removes_non_empty_directory_after_confirmation :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp(
		"",
		"twin-commander-delete-dir-*",
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

	directory_path := filepath.join({temp_path, "documents"}) or_else ""
	defer delete(directory_path)
	nested_path := filepath.join({directory_path, "note.txt"}) or_else ""
	defer delete(nested_path)
	testing.expect(t, os.make_directory(directory_path) == nil)
	testing.expect(t, os.write_entire_file_from_string(nested_path, "note") == nil)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], temp_path) == nil)
	app.panels[0].selected = 1
	delete_selected_entry(&app)
	handle_delete_event(&app, tui.Event{kind = .Text, text = 'T'})
	_, deleted_err := os.stat(directory_path, context.allocator)
	testing.expect_value(t, deleted_err, os.Error(.Not_Exist))
}
