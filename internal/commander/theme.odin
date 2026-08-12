package commander

import "tc:internal/tui"

Theme_Mode :: enum {
	Dark,
	Light,
}

Theme :: struct {
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

theme_for :: proc(mode: Theme_Mode) -> Theme {
	switch mode {
	case .Light:
		return Theme {
			screen = {foreground = .Black, background = .White},
			panel_border_active = {foreground = .Blue, background = .White, attributes = {.Bold}},
			panel_border_inactive = {
				foreground = .Black,
				background = .White,
				attributes = {.Dim},
			},
			panel_row_active = {foreground = .Black, background = .White},
			panel_row_inactive = {foreground = .Black, background = .White, attributes = {.Dim}},
			selection_active = {foreground = .White, background = .Blue, attributes = {.Bold}},
			selection_inactive = {
				foreground = .Blue,
				background = .White,
				attributes = {.Underline},
			},
			status = {foreground = .White, background = .Blue},
			keys = {foreground = .White, background = .Black},
			dialog_surface = {foreground = .White, background = .Black},
			dialog_border = {foreground = .White, background = .Black, attributes = {.Bold}},
			dialog_accent = {
				foreground = .White,
				background = .Black,
				attributes = {.Bold, .Underline},
			},
			dialog_action = {foreground = .Black, background = .White, attributes = {.Bold}},
			progress_track = {background = .White},
			progress_fill = {background = .Cyan},
		}
	case .Dark:
		return Theme {
			screen = {foreground = .White, background = .Black},
			panel_border_active = {foreground = .Cyan, background = .Black, attributes = {.Bold}},
			panel_border_inactive = {
				foreground = .White,
				background = .Black,
				attributes = {.Dim},
			},
			panel_row_active = {foreground = .White, background = .Black},
			panel_row_inactive = {foreground = .White, background = .Black, attributes = {.Dim}},
			selection_active = {foreground = .Black, background = .Cyan, attributes = {.Bold}},
			selection_inactive = {
				foreground = .Cyan,
				background = .Black,
				attributes = {.Underline},
			},
			status = {foreground = .Black, background = .Cyan},
			keys = {foreground = .Black, background = .White},
			dialog_surface = {foreground = .Black, background = .White},
			dialog_border = {foreground = .Black, background = .White, attributes = {.Bold}},
			dialog_accent = {
				foreground = .Black,
				background = .White,
				attributes = {.Bold, .Underline},
			},
			dialog_action = {foreground = .White, background = .Black, attributes = {.Bold}},
			progress_track = {background = .Black},
			progress_fill = {background = .Cyan},
		}
	}
	return {}
}
