package commander

import "core:os"
import "core:path/filepath"
import "core:testing"
import "tc:internal/tui"

@(test)
panel_select_name_restores_file_selection :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp("", "twin-commander-external-*", context.allocator)
	if !testing.expect(t, temp_err == nil) do return
	defer delete(temp_path)
	defer os.remove_all(temp_path)

	first_path := filepath.join({temp_path, "first.txt"}) or_else ""
	second_path := filepath.join({temp_path, "second.txt"}) or_else ""
	defer delete(first_path)
	defer delete(second_path)
	testing.expect(t, os.write_entire_file_from_string(first_path, "first") == nil)
	testing.expect(t, os.write_entire_file_from_string(second_path, "second") == nil)

	panel: Panel_State
	defer panel_destroy(&panel)
	testing.expect(t, panel_load(&panel, temp_path) == nil)
	testing.expect(t, panel_select_name(&panel, "second.txt"))
	testing.expect_value(t, panel.selected, 2)
	testing.expect(t, !panel_select_name(&panel, "missing.txt"))
	testing.expect_value(t, panel.selected, 2)
}

@(test)
view_and_edit_letter_shortcuts_dispatch_without_function_keys :: proc(t: ^testing.T) {
	app: App_State
	defer app_destroy(&app)
	ctx: tui.Context
	running := true
	for letter in "veVE" {
		set_status(&app, "")
		handle_event(&ctx, &app, tui.Event{kind = .Text, text = letter}, &running)
		testing.expect_value(t, app.status, tr("Wybierz plik"))
		testing.expect(t, running)
	}
	set_status(&app, "")
	handle_event(&ctx, &app, tui.Event{kind = .Text, text = 'e', modifiers = {.Control}}, &running)
	testing.expect_value(t, app.status, "")
}
