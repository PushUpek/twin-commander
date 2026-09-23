package commander

import "core:os"
import "core:strings"
import "core:testing"
import "tc:pkg/tui"

@(test)
action_hints_bracket_keys_without_changing_descriptions :: proc(t: ^testing.T) {
	formatted := format_action_hints(" Enter/T Tak   Esc/N Nie   W Wszystkie ")
	defer delete(formatted)
	testing.expect_value(t, formatted, "[Enter/T] Tak  [Esc/N] Nie  [W] Wszystkie")
	localized := format_action_hints(" Enter/T Yes   Esc/N No ")
	defer delete(localized)
	testing.expect(t, strings.contains(localized, "[Enter/T] Yes"))
}

count_visible_action_keys :: proc(buffer: ^tui.Buffer, theme: Theme) -> int {
	count := 0
	for cell in buffer.cells {
		if cell.character == '[' && cell.style == theme.dialog_action do count += 1
	}
	return count
}

action_row_contains :: proc(buffer: ^tui.Buffer, row: int, key: string, theme: Theme) -> bool {
	for x in 0 ..< buffer.width - len(key) + 1 {
		found := true
		for index in 0 ..< len(key) {
			cell := tui.buffer_get(buffer, x + index, row)
			if cell.character != rune(key[index]) || cell.style != theme.dialog_action {
				found = false
				break
			}
		}
		if found do return true
	}
	return false
}

@(test)
dialog_action_hints_remain_visible_in_both_themes :: proc(t: ^testing.T) {
	modes := []Theme_Mode {.Dark, .Light}
	for mode in modes {
		theme := theme_for(mode)
		defer destroy_theme(&theme)
		buffer: tui.Buffer
		tui.buffer_init(&buffer, 56, 24)
		defer tui.buffer_destroy(&buffer)
		app: App_State

		draw_exit_dialog(&buffer, 56, 24, theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 2)
		tui.buffer_clear(&buffer)
		draw_overwrite_dialog(&buffer, 56, 24, "plik.txt", theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 3)
		tui.buffer_clear(&buffer)
		draw_move_overwrite_dialog(&buffer, 56, 24, "plik.txt", theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 3)
		tui.buffer_clear(&buffer)
		draw_delete_dialog(&buffer, 56, 24, "plik.txt", theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 3)
		tui.buffer_clear(&buffer)
		draw_bulk_confirmation_dialog(&buffer, 56, 24, "plik.txt", 2, .Copy, theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 2)
		tui.buffer_clear(&buffer)
		draw_name_edit_dialog(&buffer, 56, 24, "", 0, "Nazwa", "Enter Zapisz", theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 2)
		tui.buffer_clear(&buffer)
		draw_operation_error_dialog(&buffer, 56, 24, "plik.txt", "Błąd", theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 3)
		tui.buffer_clear(&buffer)
		draw_help_dialog(&buffer, 56, 24, theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 2)
		tui.buffer_clear(&buffer)
		app.menu_kind = .User
		draw_menu_dialog(&buffer, 56, 24, &app, theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 2)
		tui.buffer_clear(&buffer)
		app.menu_kind = .Main
		draw_menu_dialog(&buffer, 56, 24, &app, theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 2)
		tui.buffer_clear(&buffer)
		draw_bookmarks_dialog(&buffer, 56, 24, &app, theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 4)
		tui.buffer_clear(&buffer)
		draw_search_results_dialog(&buffer, 56, 24, &app, theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 2)
		tui.buffer_clear(&buffer)
		draw_properties_dialog(&buffer, 56, 24, &app, theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 2)
		tui.buffer_clear(&buffer)
		app.property_is_symlink = true
		draw_properties_dialog(&buffer, 56, 24, &app, theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 1)
		tui.buffer_clear(&buffer)
		draw_background_dialog(&buffer, 56, 24, &app, theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 4)
		tui.buffer_clear(&buffer)
		draw_checksum_dialog(&buffer, 56, 24, &app, theme)
		testing.expect_value(t, count_visible_action_keys(&buffer, theme), 3)
	}
}

@(test)
viewer_close_hint_survives_narrow_widths :: proc(t: ^testing.T) {
	theme := theme_for(.Light)
	defer destroy_theme(&theme)
	buffer: tui.Buffer
	defer tui.buffer_destroy(&buffer)
	app: App_State
	widths := []int {80, 56, 20}
	for width in widths {
		tui.buffer_init(&buffer, width, 24)
		draw_viewer(&buffer, width, 24, &app, theme)
		testing.expect(t, action_row_contains(&buffer, 22, "[Esc]", theme))
		if width == 56 do testing.expect(t, action_row_contains(&buffer, 22, "[H]", theme))
	}
}

@(test)
overwrite_dialog_is_centered_and_contains_actions :: proc(t: ^testing.T) {
	buffer: tui.Buffer
	tui.buffer_init(&buffer, 80, 24)
	defer tui.buffer_destroy(&buffer)

	theme := theme_for(.Dark)
	defer destroy_theme(&theme)
	draw_overwrite_dialog(&buffer, 80, 24, "raport.txt", theme)

	testing.expect_value(t, tui.buffer_get(&buffer, 10, 8).character, '┌')
	testing.expect_value(t, tui.buffer_get(&buffer, 69, 8).character, '┐')
	testing.expect_value(t, tui.buffer_get(&buffer, 10, 14).character, '└')
	testing.expect_value(t, tui.buffer_get(&buffer, 69, 14).character, '┘')
	testing.expect_value(t, tui.buffer_get(&buffer, 13, 11).character, 'r')
	testing.expect_value(t, tui.buffer_get(&buffer, 14, 13).character, 'E')
	testing.expect_value(
		t,
		tui.buffer_get(&buffer, 12, 10).style.background_rgb,
		tui.rgb(0x2A2C35),
	)
	testing.expect_value(
		t,
		tui.buffer_get(&buffer, 14, 13).style.background_rgb,
		tui.rgb(0x7FB4CA),
	)
	testing.expect(t, .Dim in tui.buffer_get(&buffer, 0, 0).style.attributes)
}

@(test)
move_edit_dialog_shows_the_editable_target_name :: proc(t: ^testing.T) {
	buffer: tui.Buffer
	tui.buffer_init(&buffer, 80, 24)
	defer tui.buffer_destroy(&buffer)

	theme := theme_for(.Dark)
	defer destroy_theme(&theme)
	draw_move_edit_dialog(&buffer, 80, 24, "raport.txt", len("raport.txt"), theme)

	testing.expect_value(t, tui.buffer_get(&buffer, 13, 11).character, rune('r'))
	testing.expect_value(t, tui.buffer_get(&buffer, 23, 11).style.background_rgb, theme.dialog_action.background_rgb)
	testing.expect_value(t, tui.buffer_get(&buffer, 14, 14).character, rune('E'))
}

@(test)
copy_progress_dialog_fills_bar_proportionally :: proc(t: ^testing.T) {
	buffer: tui.Buffer
	tui.buffer_init(&buffer, 80, 24)
	defer tui.buffer_destroy(&buffer)

	theme := theme_for(.Dark)
	defer destroy_theme(&theme)
	draw_copy_progress_dialog(&buffer, 80, 24, "film.bin", 50, theme)

	// Dla szerokości 80 pasek ma 54 komórki, więc połowa kończy się po 27.
	testing.expect_value(t, tui.buffer_get(&buffer, 13, 12).style.background_rgb, tui.rgb(0x7AA89F))
	testing.expect_value(t, tui.buffer_get(&buffer, 39, 12).style.background_rgb, tui.rgb(0x7AA89F))
	testing.expect_value(t, tui.buffer_get(&buffer, 40, 12).style.background_rgb, tui.rgb(0x43464E))
	testing.expect_value(t, tui.buffer_get(&buffer, 38, 13).character, '5')
}

@(test)
default_themes_keep_text_and_surfaces_contrasting :: proc(t: ^testing.T) {
	dark := theme_for(.Dark)
	defer destroy_theme(&dark)
	light := theme_for(.Light)
	defer destroy_theme(&light)

	testing.expect_value(t, dark.name, "Kanso Mist")
	testing.expect_value(t, dark.screen.background_rgb, tui.rgb(0x22262D))
	testing.expect_value(t, dark.screen.foreground_rgb, tui.rgb(0xC5C9C7))
	testing.expect_value(t, dark.dialog_surface.background_rgb, tui.rgb(0x2A2C35))
	testing.expect_value(t, light.name, "Kanso Pearl")
	testing.expect_value(t, light.screen.background_rgb, tui.rgb(0xF2F1EF))
	testing.expect_value(t, light.screen.foreground_rgb, tui.rgb(0x22262D))
	testing.expect_value(t, light.dialog_surface.background_rgb, tui.rgb(0xE2E1DF))
	dialog_styles := []tui.Style {
		dark.dialog_surface,
		dark.dialog_border,
		dark.dialog_accent,
		dark.dialog_action,
		light.dialog_surface,
		light.dialog_border,
		light.dialog_accent,
		light.dialog_action,
	}
	for style in dialog_styles {
		testing.expect(t, style.foreground_rgb != style.background_rgb)
	}
}

@(test)
macos_system_appearance_maps_to_light_and_dark :: proc(t: ^testing.T) {
	light, ok := theme_mode_from_apple_style("", false)
	testing.expect(t, ok)
	testing.expect_value(t, light, Theme_Mode.Light)

	dark: Theme_Mode
	dark, ok = theme_mode_from_apple_style("Dark\n", true)
	testing.expect(t, ok)
	testing.expect_value(t, dark, Theme_Mode.Dark)
}

@(test)
system_appearance_selects_the_matching_theme :: proc(t: ^testing.T) {
	app := App_State{theme_mode = .Dark}
	defer app_destroy(&app)
	apply_appearance(&app, .Light)
	testing.expect_value(t, app.theme_mode, Theme_Mode.Light)

	apply_appearance(&app, .Dark)
	testing.expect_value(t, app.theme_mode, Theme_Mode.Dark)

	apply_appearance(&app, .Unknown)
	testing.expect_value(t, app.theme_mode, Theme_Mode.Dark)

	app.theme_overridden = true
	apply_appearance(&app, .Light)
	testing.expect_value(t, app.theme_mode, Theme_Mode.Dark)
}

@(test)
human_readable_file_sizes :: proc(t: ^testing.T) {
	test_cases := []struct {
		size:     i64,
		expected: string,
	} {
		{0, "0B"},
		{1023, "1023B"},
		{1024, "1.0K"},
		{1536, "1.5K"},
		{10 * 1024, "10K"},
		{1024 * 1024, "1.0M"},
		{5 * 1024 * 1024 * 1024, "5.0G"},
	}

	for test_case in test_cases {
		buffer: [16]byte
		actual := format_file_size(buffer[:], test_case.size)
		testing.expect_value(t, actual, test_case.expected)
	}
}

@(test)
symbolic_file_permissions :: proc(t: ^testing.T) {
	test_cases := []struct {
		permissions: os.Permissions,
		expected:    string,
	}{{os.perm(0o755), "rwxr-xr-x"}, {os.perm(0o644), "rw-r--r--"}, {os.perm(0), "---------"}}

	for test_case in test_cases {
		buffer: [9]byte
		actual := format_permissions(buffer[:], test_case.permissions)
		testing.expect_value(t, actual, test_case.expected)
	}
}

@(test)
panel_renders_metadata_columns_below_header :: proc(t: ^testing.T) {
	buffer: tui.Buffer
	tui.buffer_init(&buffer, 40, 8)
	defer tui.buffer_destroy(&buffer)

	files := []os.File_Info {
		{name = "note.txt", size = 1536, mode = os.perm(0o640), type = .Regular},
	}
	state := Panel_State {
		path     = "/tmp",
		files    = files,
		selected = 1,
	}
	draw_panel(&buffer, tui.Rect{width = 40, height = 8}, &state, true, {})

	testing.expect_value(t, tui.buffer_get(&buffer, 4, 1).character, rune('N'))
	testing.expect_value(t, tui.buffer_get(&buffer, 19, 1).character, rune('R'))
	testing.expect_value(t, tui.buffer_get(&buffer, 27, 1).character, rune('U'))
	testing.expect_value(t, tui.buffer_get(&buffer, 2, 2).character, rune('↰'))
	testing.expect_value(t, tui.buffer_get(&buffer, 4, 2).character, rune('.'))
	testing.expect_value(t, tui.buffer_get(&buffer, 2, 3).character, rune('≡'))
	testing.expect_value(t, tui.buffer_get(&buffer, 4, 3).character, rune('n'))
	testing.expect_value(t, tui.buffer_get(&buffer, 22, 3).character, rune('1'))
	testing.expect_value(t, tui.buffer_get(&buffer, 29, 3).character, rune('r'))
}

@(test)
marked_panel_entry_changes_the_whole_row_color_without_prefix :: proc(t: ^testing.T) {
	buffer: tui.Buffer
	tui.buffer_init(&buffer, 40, 8)
	defer tui.buffer_destroy(&buffer)
	theme := theme_for(.Dark)
	defer destroy_theme(&theme)
	files := []os.File_Info {{name = "note.txt", type = .Regular}}
	state := Panel_State{path = "/tmp", files = files, selected = 1}
	append(&state.marked, "note.txt")
	defer delete(state.marked)
	draw_panel(&buffer, tui.Rect{width = 40, height = 8}, &state, true, theme)
	testing.expect_value(t, tui.buffer_get(&buffer, 2, 3).character, rune('≡'))
	testing.expect_value(t, tui.buffer_get(&buffer, 4, 3).character, rune('n'))
	testing.expect_value(t, tui.buffer_get(&buffer, 2, 3).style.background_rgb, theme.marked_active.background_rgb)
	testing.expect_value(t, tui.buffer_get(&buffer, 38, 3).style.background_rgb, theme.marked_active.background_rgb)
}

@(test)
file_type_icons_cover_directories_and_common_file_categories :: proc(t: ^testing.T) {
	test_cases := []struct {
		file:     os.File_Info,
		expected: rune,
	}{
		{{name = "documents", type = .Directory}, '▸'},
		{{name = "main.ODIN", type = .Regular}, 'λ'},
		{{name = "photo.png", type = .Regular}, '◈'},
		{{name = "backup.tar.gz", type = .Regular}, '▣'},
		{{name = "notes.md", type = .Regular}, '≡'},
		{{name = "unknown.bin", type = .Regular}, '·'},
		{{name = "shortcut", type = .Symlink}, '↗'},
	}

	for test_case in test_cases {
		testing.expect_value(t, file_type_icon(test_case.file), test_case.expected)
	}
}
