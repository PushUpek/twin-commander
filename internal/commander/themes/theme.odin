package commander_themes

import "tc:internal/tui"

Mode :: enum {
	Dark,
	Light,
}

Theme :: struct {
	name:                  string,
	screen:                tui.Style,
	panel_border_active:   tui.Style,
	panel_border_inactive: tui.Style,
	panel_row_active:      tui.Style,
	panel_row_inactive:    tui.Style,
	selection_active:      tui.Style,
	selection_inactive:    tui.Style,
	status:                tui.Style,
	keys:                  tui.Style,
	dialog_surface:        tui.Style,
	dialog_border:         tui.Style,
	dialog_accent:         tui.Style,
	dialog_action:         tui.Style,
	progress_track:        tui.Style,
	progress_fill:         tui.Style,
}
