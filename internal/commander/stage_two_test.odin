package commander

import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"
import "tc:internal/tui"

@(test)
recursive_search_finds_nested_entry_and_opens_its_parent :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-search-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	nested := filepath.join({root, "nested"}) or_else ""
	file := filepath.join({nested, "unique-needle.txt"}) or_else ""
	defer delete(nested)
	defer delete(file)
	testing.expect(t, os.make_directory(nested) == nil)
	testing.expect(t, os.write_entire_file_from_string(file, "found") == nil)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], root) == nil)
	app.search_query = strings.clone("needle") or_else ""
	run_search(&app)
	testing.expect_value(t, len(app.search_results), 1)
	expected_file, file_abs_err := filepath.abs(file, context.allocator)
	if !testing.expect(t, file_abs_err == nil) do return
	defer delete(expected_file)
	testing.expect_value(t, app.search_results[0], expected_file)
	open_search_result(&app)
	expected, abs_err := filepath.abs(nested, context.allocator)
	if !testing.expect(t, abs_err == nil) do return
	defer delete(expected)
	testing.expect_value(t, app.panels[0].path, expected)
	testing.expect_value(t, app.panels[0].files[app.panels[0].selected - 1].name, "unique-needle.txt")
}

@(test)
properties_apply_valid_octal_permissions :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-properties-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	file := filepath.join({root, "mode.txt"}) or_else ""
	defer delete(file)
	testing.expect(t, os.write_entire_file_from_string(file, "mode") == nil)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], root) == nil)
	testing.expect(t, panel_select_name(&app.panels[0], "mode.txt"))
	begin_properties(&app)
	testing.expect(t, app.properties_pending)
	replace_edit_name(&app.property_mode, "600")
	app.property_mode_cursor = 3
	handle_properties_event(&app, tui.Event{kind = .Key, key = .Enter})
	testing.expect(t, !app.properties_pending)
	info, stat_err := os.lstat(file, context.allocator)
	if !testing.expect(t, stat_err == nil) do return
	defer os.file_info_delete(info, context.allocator)
	testing.expect_value(t, transmute(u32)info.mode & 0o777, u32(0o600))
	testing.expect(t, !parse_mode_accepts_invalid_values())
}

parse_mode_accepts_invalid_values :: proc() -> bool {
	_, too_short := parse_octal_mode("77")
	_, non_octal := parse_octal_mode("889")
	return too_short || non_octal
}

@(test)
bookmarks_add_open_and_remove_directories_without_duplicates :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-bookmarks-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	child := filepath.join({root, "child"}) or_else ""
	defer delete(child)
	testing.expect(t, os.make_directory(child) == nil)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], root) == nil)
	testing.expect(t, add_current_bookmark(&app))
	testing.expect(t, !add_current_bookmark(&app))
	testing.expect_value(t, len(app.bookmarks), 1)
	testing.expect(t, panel_load(&app.panels[0], child) == nil)
	open_selected_bookmark(&app)
	expected, abs_err := filepath.abs(root, context.allocator)
	if !testing.expect(t, abs_err == nil) do return
	defer delete(expected)
	testing.expect_value(t, app.panels[0].path, expected)
	testing.expect(t, remove_selected_bookmark(&app))
	testing.expect_value(t, len(app.bookmarks), 0)
}

@(test)
panel_comparison_marks_missing_and_different_entries_on_both_sides :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-compare-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	left := filepath.join({root, "left"}) or_else ""
	right := filepath.join({root, "right"}) or_else ""
	defer delete(left)
	defer delete(right)
	testing.expect(t, os.make_directory(left) == nil)
	testing.expect(t, os.make_directory(right) == nil)
	for directory in ([]string{left, right}) {
		shared := filepath.join({directory, "shared"}) or_else ""
		testing.expect(t, os.make_directory(shared) == nil)
		delete(shared)
		different := filepath.join({directory, "different.txt"}) or_else ""
		content := "a"
		if directory == right do content = "different-size"
		testing.expect(t, os.write_entire_file_from_string(different, content) == nil)
		delete(different)
	}
	left_only := filepath.join({left, "left-only.txt"}) or_else ""
	right_only := filepath.join({right, "right-only.txt"}) or_else ""
	defer delete(left_only)
	defer delete(right_only)
	testing.expect(t, os.write_entire_file_from_string(left_only, "left") == nil)
	testing.expect(t, os.write_entire_file_from_string(right_only, "right") == nil)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], left) == nil)
	testing.expect(t, panel_load(&app.panels[1], right) == nil)
	compare_panels(&app)
	testing.expect_value(t, len(app.panels[0].marked), 2)
	testing.expect_value(t, len(app.panels[1].marked), 2)
	testing.expect(t, panel_is_marked(&app.panels[0], "different.txt"))
	testing.expect(t, panel_is_marked(&app.panels[0], "left-only.txt"))
	testing.expect(t, panel_is_marked(&app.panels[1], "different.txt"))
	testing.expect(t, panel_is_marked(&app.panels[1], "right-only.txt"))
	testing.expect(t, !panel_is_marked(&app.panels[0], "shared"))
}
