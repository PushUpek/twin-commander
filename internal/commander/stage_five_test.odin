package commander

import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"
import "tc:internal/tui"

@(test)
remote_listing_paths_and_navigation :: proc(t: ^testing.T) {
	testing.expect(t, remote_path_valid("sftp:folder"))
	testing.expect(t, !remote_path_valid("/tmp/local"))
	testing.expect(t, !remote_path_valid("bad name:folder"))
	root_parent := remote_parent("server:/folder")
	defer delete(root_parent)
	testing.expect_value(t, root_parent, "server:/")
	deep_parent := remote_parent("server:folder/sub")
	defer delete(deep_parent)
	testing.expect_value(t, deep_parent, "server:folder")
	root := remote_parent("server:")
	defer delete(root)
	testing.expect_value(t, root, "server:")

	listing := `[{"Name":"dir","IsDir":true,"Size":0},{"Name":"note.txt","IsDir":false,"Size":12},{"Name":".secret","IsDir":false,"Size":1},{"Name":"../unsafe","IsDir":false,"Size":1}]`
	path, files, err := remote_parse_listing("server:", transmute([]byte)listing, {})
	if !testing.expect(t, err == nil) do return
	defer delete(path)
	defer os.file_info_slice_delete(files, context.allocator)
	testing.expect_value(t, len(files), 2)
	testing.expect_value(t, files[0].name, "dir")
	testing.expect_value(t, files[0].fullpath, "server:dir")
	testing.expect_value(t, files[1].name, "note.txt")
	testing.expect_value(t, files[1].size, i64(12))
}

@(test)
remote_path_editor_accepts_directory_separator :: proc(t: ^testing.T) {
	app := App_State{remote_text = strings.clone("server:folder") or_else "", remote_cursor = len("server:folder"), remote_edit_pending = true}
	defer app_destroy(&app)
	handle_remote_edit_event(&app, tui.Event{kind = .Text, text = '/'})
	testing.expect_value(t, app.remote_text, "server:folder/")
	testing.expect(t, app.remote_edit_pending)
}

@(test)
configurable_shortcut_parser_preserves_modifiers :: proc(t: ^testing.T) {
	binding, ok := shortcut_parse(.View, "Ctrl-F12")
	testing.expect(t, ok)
	testing.expect(t, shortcut_matches(binding, tui.Event{kind = .Key, key = .F12, modifiers = {.Control}}))
	testing.expect(t, !shortcut_matches(binding, tui.Event{kind = .Key, key = .F12}))
	letter, letter_ok := shortcut_parse(.Sync, "Ctrl-Y")
	testing.expect(t, letter_ok)
	testing.expect(t, shortcut_matches(letter, tui.Event{kind = .Text, text = 'y', modifiers = {.Control}}))
	_, invalid := shortcut_parse(.View, "Ctrl-Unknown")
	testing.expect(t, !invalid)
}

@(test)
recursive_compare_and_one_way_sync_keep_destination_extras :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-sync-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	source := filepath.join({root, "source"}) or_else ""
	destination := filepath.join({root, "destination"}) or_else ""
	defer delete(source)
	defer delete(destination)
	testing.expect(t, os.make_directory(source) == nil)
	testing.expect(t, os.make_directory(destination) == nil)
	nested := filepath.join({source, "nested"}) or_else ""
	defer delete(nested)
	testing.expect(t, os.make_directory(nested) == nil)
	new_file := filepath.join({nested, "new.txt"}) or_else ""
	extra_file := filepath.join({destination, "extra.txt"}) or_else ""
	dest_new := filepath.join({destination, "nested", "new.txt"}) or_else ""
	defer delete(new_file)
	defer delete(extra_file)
	defer delete(dest_new)
	testing.expect(t, os.write_entire_file_from_string(new_file, "new") == nil)
	testing.expect(t, os.write_entire_file_from_string(extra_file, "keep") == nil)
	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], source) == nil)
	testing.expect(t, panel_load(&app.panels[1], destination) == nil)
	compare_recursive(&app)
	testing.expect(t, panel_is_marked(&app.panels[0], "nested"))
	testing.expect(t, panel_is_marked(&app.panels[1], "extra.txt"))
	begin_sync(&app)
	testing.expect(t, app.sync_pending)
	testing.expect_value(t, app.sync_new_count, 2)
	testing.expect_value(t, app.sync_extra_count, 1)
	handle_sync_event(&app, tui.Event{kind = .Key, key = .Enter})
	testing.expect(t, !app.sync_pending)
	data, read_err := os.read_entire_file(dest_new, context.allocator)
	if testing.expect(t, read_err == nil) {
		testing.expect_value(t, string(data), "new")
		delete(data)
	}
	extra_info, extra_err := os.stat(extra_file, context.temp_allocator)
	testing.expect(t, extra_err == nil)
	if extra_err == nil do os.file_info_delete(extra_info, context.temp_allocator)
}

@(test)
tree_and_quick_panel_modes_load_selected_content :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-modes-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	nested := filepath.join({root, "nested"}) or_else ""
	file := filepath.join({root, "note.txt"}) or_else ""
	defer delete(nested)
	defer delete(file)
	testing.expect(t, os.make_directory(nested) == nil)
	testing.expect(t, os.write_entire_file_from_string(file, "preview") == nil)
	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], root) == nil)
	testing.expect(t, panel_load(&app.panels[1], root) == nil)
	panel_mode_cycle(&app)
	testing.expect_value(t, app.panels[0].mode, Panel_Mode.Tree)
	testing.expect(t, len(app.panels[0].tree_paths) >= 3)
	app.panels[0].mode = .Quick
	panel_select_name(&app.panels[0], "note.txt")
	panel_preview_update(&app)
	testing.expect_value(t, string(app.panels[0].preview_data), "preview")
}

@(test)
viewer_json_formatting_and_colors_preserve_source :: proc(t: ^testing.T) {
	source := "{\"key\":\"value\",\"n\":12,\"nested\":{\"ok\":true}}"
	formatted, ok := viewer_pretty_json(transmute([]byte)source)
	if !testing.expect(t, ok) do return
	defer delete(formatted)
	testing.expect_value(t, string(formatted), "{\n  \"key\": \"value\",\n  \"n\": 12,\n  \"nested\": {\n    \"ok\": true\n  }\n}\n")
	_, invalid := viewer_pretty_json(transmute([]byte)(string("{broken")))
	testing.expect(t, !invalid)

	app: App_State
	defer app_destroy(&app)
	app.viewer_data = transmute([]byte)(strings.clone(source) or_else "")
	app.viewer_formatted_data = transmute([]byte)(strings.clone(string(formatted)) or_else "")
	app.viewer_json_available = true
	viewer_index_lines(app.viewer_data, &app.viewer_line_starts)
	viewer_index_lines(app.viewer_formatted_data, &app.viewer_formatted_line_starts)
	viewer_toggle_format(&app)
	testing.expect(t, app.viewer_formatted)
	testing.expect_value(t, len(viewer_active_lines(&app)), 7)
	app.viewer_query = strings.clone("ok") or_else ""
	testing.expect(t, viewer_find_next(&app))
	testing.expect_value(t, app.viewer_top, 4)
	app.viewer_hex = true
	testing.expect_value(t, len(viewer_active_lines(&app)), 1)

	theme := theme_for(.Dark)
	defer destroy_theme(&theme)
	buffer: tui.Buffer
	tui.buffer_init(&buffer, 40, 3)
	defer tui.buffer_destroy(&buffer)
	viewer_draw_json_line(&buffer, 0, 0, "{\"key\":\"value\",\"n\":12}", 40, theme)
	testing.expect_value(t, tui.buffer_get(&buffer, 1, 0).style, theme.viewer_json_key)
	testing.expect_value(t, tui.buffer_get(&buffer, 7, 0).style, theme.viewer_json_string)
}

@(test)
checksum_algorithm_switch_matches_known_vectors :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-hash-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	path := filepath.join({root, "abc.txt"}) or_else ""
	defer delete(path)
	testing.expect(t, os.write_entire_file_from_string(path, "abc") == nil)
	vectors := []struct {algorithm: Checksum_Algorithm, hash: string} {
		{.MD5, "900150983cd24fb0d6963f7d28e17f72"},
		{.SHA1, "a9993e364706816aba3e25717850c26c9cd0d89d"},
		{.SHA224, "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7"},
		{.SHA256, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"},
		{.SHA384, "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7"},
		{.SHA512, "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"},
	}
	for vector in vectors {
		hash, ok := checksum_file(path, vector.algorithm)
		testing.expect(t, ok)
		testing.expect_value(t, hash, vector.hash)
		delete(hash)
	}
	app := App_State{checksum_path = strings.clone(path) or_else "", checksum_algorithm = .SHA256}
	defer app_destroy(&app)
	app.checksum_hash, _ = checksum_file(path, .SHA256)
	handle_checksum_event(&app, tui.Event{kind = .Key, key = .Tab})
	testing.expect_value(t, app.checksum_algorithm, Checksum_Algorithm.MD5)
	testing.expect_value(t, app.checksum_hash, vectors[0].hash)
}
