package commander

import "core:os"
import "core:path/filepath"
import "core:testing"

@(test)
panel_refresh_preserves_selection_and_existing_marks :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp("", "twin-commander-refresh-*", context.allocator)
	if !testing.expect(t, temp_err == nil) do return
	defer delete(temp_path)
	defer os.remove_all(temp_path)
	names := [?]string{"alpha.txt", "beta.txt"}
	for name in names {
		path := filepath.join({temp_path, name}) or_else ""
		testing.expect(t, os.write_entire_file_from_string(path, name) == nil)
		delete(path)
	}

	panel: Panel_State
	defer panel_destroy(&panel)
	testing.expect(t, panel_load(&panel, temp_path) == nil)
	testing.expect(t, panel_select_name(&panel, "beta.txt"))
	panel_toggle_mark(&panel)
	// toggle_mark advances only when another row exists; restore the intended cursor explicitly.
	testing.expect(t, panel_select_name(&panel, "beta.txt"))
	testing.expect(t, panel_refresh(&panel) == nil)
	testing.expect_value(t, panel.files[panel.selected - 1].name, "beta.txt")
	testing.expect(t, panel_is_marked(&panel, "beta.txt"))
}

@(test)
panel_history_moves_back_and_forward_without_creating_duplicate_entries :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp("", "twin-commander-history-*", context.allocator)
	if !testing.expect(t, temp_err == nil) do return
	defer delete(temp_path)
	defer os.remove_all(temp_path)
	child := filepath.join({temp_path, "child"}) or_else ""
	defer delete(child)
	testing.expect(t, os.make_directory(child) == nil)

	panel: Panel_State
	defer panel_destroy(&panel)
	testing.expect(t, panel_load(&panel, temp_path) == nil)
	testing.expect(t, panel_load(&panel, child) == nil)
	testing.expect_value(t, len(panel.history), 2)
	testing.expect(t, panel_history_move(&panel, -1) == nil)
	testing.expect_value(t, panel.path, panel.history[0])
	testing.expect(t, panel_history_move(&panel, 1) == nil)
	testing.expect_value(t, panel.path, panel.history[1])
	testing.expect_value(t, len(panel.history), 2)
}

@(test)
quick_search_and_group_patterns_update_panel_selection :: proc(t: ^testing.T) {
	panel := Panel_State{
		files = make([]os.File_Info, 3),
	}
	defer delete(panel.files)
	panel.files[0].name = "alpha.txt"
	panel.files[1].name = "beta.log"
	panel.files[2].name = "bravo.txt"
	defer panel_clear_marks(&panel)
	defer delete(panel.marked)
	defer delete(panel.quick_search)

	testing.expect(t, panel_quick_search(&panel, 'b'))
	testing.expect_value(t, panel.selected, 2)
	testing.expect(t, panel_quick_search(&panel, 'r'))
	testing.expect_value(t, panel.selected, 3)
	testing.expect(t, panel_quick_search_backspace(&panel))
	testing.expect_value(t, panel.quick_search, "")

	testing.expect(t, panel_mark_pattern(&panel, "*.txt", true))
	testing.expect(t, panel_is_marked(&panel, "alpha.txt"))
	testing.expect(t, panel_is_marked(&panel, "bravo.txt"))
	testing.expect(t, !panel_is_marked(&panel, "beta.log"))
	panel_invert_marks(&panel)
	testing.expect(t, !panel_is_marked(&panel, "alpha.txt"))
	testing.expect(t, panel_is_marked(&panel, "beta.log"))
}

@(test)
enter_follows_a_symlink_that_points_to_a_directory :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp("", "twin-commander-link-dir-*", context.allocator)
	if !testing.expect(t, temp_err == nil) do return
	defer delete(temp_path)
	defer os.remove_all(temp_path)
	target := filepath.join({temp_path, "target"}) or_else ""
	link := filepath.join({temp_path, "linked"}) or_else ""
	defer delete(target)
	defer delete(link)
	testing.expect(t, os.make_directory(target) == nil)
	testing.expect(t, os.symlink("target", link) == nil)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], temp_path) == nil)
	testing.expect(t, panel_select_name(&app.panels[0], "linked"))
	enter_selected_directory(&app)
	expected_target, abs_err := filepath.abs(target, context.allocator)
	if !testing.expect(t, abs_err == nil) do return
	defer delete(expected_target)
	testing.expect_value(t, app.panels[0].path, expected_target)
}
