package commander

import "core:testing"
import "tc:internal/tui"

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
