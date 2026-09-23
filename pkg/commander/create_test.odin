package commander

import "core:os"
import "core:path/filepath"
import "core:testing"
import "tc:pkg/tui"

@(test)
f7_creates_files_and_nested_directories_without_overwriting :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-create-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	app: App_State
	defer app_destroy(&app)
	for i in 0 ..< 2 do testing.expect(t, panel_load(&app.panels[i], root) == nil)
	app.active_panel = 1
	running := true
	ctx: tui.Context

	for name in ([]string{"żółw.txt", "folder/", "a/b/c", "a/b/c/"}) {
		handle_event(&ctx, &app, tui.Event{kind = .Key, key = .F7}, &running)
		testing.expect(t, app.create_edit_pending)
		for r in name do handle_event(&ctx, &app, tui.Event{kind = .Text, text = r}, &running)
		testing.expect_value(t, app.create_name, name)
		handle_event(&ctx, &app, tui.Event{kind = .Key, key = .Enter}, &running)
		testing.expectf(t, !app.create_edit_pending, "creation failed: %s", app.status)
		testing.expect(t, app.panels[1].selected > 0)
		selected := app.panels[1].files[app.panels[1].selected - 1]
		expected_name := name
		if name == "folder/" do expected_name = "folder"
		if name == "a/b/c" || name == "a/b/c/" do expected_name = "a"
		testing.expect_value(t, selected.name, expected_name)
		path := filepath.join({root, name}) or_else ""
		info, stat_err := os.stat(path, context.allocator)
		testing.expect(t, stat_err == nil)
		if stat_err == nil {
			expected := os.File_Type.Directory
			if name == "żółw.txt" do expected = .Regular
			testing.expect_value(t, info.type, expected)
			if expected == .Regular do testing.expect_value(t, info.size, i64(0))
			os.file_info_delete(info, context.allocator)
		}
		delete(path)
	}
	testing.expect_value(t, len(app.panels[0].files), 3)
	testing.expect_value(t, len(app.panels[1].files), 3)
	file := filepath.join({root, "żółw.txt"}) or_else ""
	defer delete(file)
	testing.expect(t, os.write_entire_file_from_string(file, "keep") == nil)
	begin_create_entry(&app)
	for r in "żółw.txt" do handle_create_edit_event(&app, tui.Event{kind = .Text, text = r})
	handle_create_edit_event(&app, tui.Event{kind = .Key, key = .Enter})
	testing.expect(t, app.create_edit_pending)
	expect_file_content(t, file, "keep")
	handle_event(&ctx, &app, tui.Event{kind = .Key, key = .Escape}, &running)
	testing.expect(t, running && !app.create_edit_pending)
	begin_create_entry(&app)
	handle_create_edit_event(&app, tui.Event{kind = .Key, key = .Enter})
	testing.expect(t, app.create_edit_pending)
	handle_create_edit_event(&app, tui.Event{kind = .Key, key = .Escape})
}
