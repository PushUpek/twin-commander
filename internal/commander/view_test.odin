package commander

import "core:testing"
import "tc:internal/tui"

@(test)
overwrite_dialog_is_centered_and_contains_actions :: proc(t: ^testing.T) {
	buffer: tui.Buffer
	tui.buffer_init(&buffer, 80, 24)
	defer tui.buffer_destroy(&buffer)

	theme := theme_for(.Dark)
	draw_overwrite_dialog(&buffer, 80, 24, "raport.txt", theme)

	testing.expect_value(t, tui.buffer_get(&buffer, 10, 8).character, '┌')
	testing.expect_value(t, tui.buffer_get(&buffer, 69, 8).character, '┐')
	testing.expect_value(t, tui.buffer_get(&buffer, 10, 14).character, '└')
	testing.expect_value(t, tui.buffer_get(&buffer, 69, 14).character, '┘')
	testing.expect_value(t, tui.buffer_get(&buffer, 13, 11).character, 'r')
	testing.expect_value(t, tui.buffer_get(&buffer, 14, 13).character, 'E')
	testing.expect_value(t, tui.buffer_get(&buffer, 12, 10).style.background, tui.Color.White)
	testing.expect_value(t, tui.buffer_get(&buffer, 14, 13).style.background, tui.Color.Black)
	testing.expect(t, .Dim in tui.buffer_get(&buffer, 0, 0).style.attributes)
}

@(test)
copy_progress_dialog_fills_bar_proportionally :: proc(t: ^testing.T) {
	buffer: tui.Buffer
	tui.buffer_init(&buffer, 80, 24)
	defer tui.buffer_destroy(&buffer)

	draw_copy_progress_dialog(&buffer, 80, 24, "film.bin", 50, theme_for(.Dark))

	// Dla szerokości 80 pasek ma 54 komórki, więc połowa kończy się po 27.
	testing.expect_value(t, tui.buffer_get(&buffer, 13, 12).style.background, tui.Color.Cyan)
	testing.expect_value(t, tui.buffer_get(&buffer, 39, 12).style.background, tui.Color.Cyan)
	testing.expect_value(t, tui.buffer_get(&buffer, 40, 12).style.background, tui.Color.Black)
	testing.expect_value(t, tui.buffer_get(&buffer, 38, 13).character, '5')
}

@(test)
default_themes_keep_text_and_surfaces_contrasting :: proc(t: ^testing.T) {
	dark := theme_for(.Dark)
	light := theme_for(.Light)

	testing.expect_value(t, dark.screen.background, tui.Color.Black)
	testing.expect_value(t, dark.screen.foreground, tui.Color.White)
	testing.expect_value(t, dark.dialog_surface.background, tui.Color.White)
	testing.expect_value(t, dark.dialog_surface.foreground, tui.Color.Black)
	testing.expect_value(t, light.screen.background, tui.Color.White)
	testing.expect_value(t, light.screen.foreground, tui.Color.Black)
	testing.expect_value(t, light.dialog_surface.background, tui.Color.Black)
	testing.expect_value(t, light.dialog_surface.foreground, tui.Color.White)
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
		testing.expect(t, style.foreground != style.background)
	}
}
