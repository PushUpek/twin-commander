package commander_themes

import "base:runtime"
import "core:os"
import "core:strconv"
import "core:strings"
import "tc:internal/tui"

load_theme_file :: proc(path: string, allocator: runtime.Allocator) -> (Theme, bool) {
	data, err := os.read_entire_file(path, context.temp_allocator)
	if err != nil {
		return {}, false
	}
	defer delete(data, context.temp_allocator)
	theme, ok := parse_theme(string(data))
	if !ok {
		return {}, false
	}
	name := strings.clone(theme.name, allocator) or_else ""
	if len(name) == 0 {
		return {}, false
	}
	theme.name = name
	return theme, true
}

theme_destroy :: proc(theme: ^Theme) {
	if theme == nil {
		return
	}
	delete(theme.name)
	theme^ = {}
}

parse_theme :: proc(data: string) -> (Theme, bool) {
	theme: Theme
	section := ""
	rest := data

	for len(rest) > 0 {
		line_end := strings.index_byte(rest, '\n')
		line: string
		if line_end < 0 {
			line = rest
			rest = ""
		} else {
			line = rest[:line_end]
			rest = rest[line_end + 1:]
		}
		line = strings.trim(line, " \t\r")
		if len(line) == 0 || line[0] == '#' {
			continue
		}

		if line[0] == '[' {
			if len(line) < 3 || line[len(line) - 1] != ']' {
				return {}, false
			}
			section = line[1:len(line) - 1]
			if _, ok := style_for_section(&theme, section); !ok {
				return {}, false
			}
			continue
		}

		equals := strings.index_byte(line, '=')
		if equals < 1 {
			return {}, false
		}
		key := strings.trim(line[:equals], " \t")
		value := strings.trim(line[equals + 1:], " \t")
		if len(section) == 0 {
			if key != "name" {
				return {}, false
			}
			name, ok := parse_quoted(value)
			if !ok {
				return {}, false
			}
			theme.name = name
			continue
		}

		style, ok := style_for_section(&theme, section)
		if !ok || !apply_style_value(style, key, value) {
			return {}, false
		}
	}

	return theme, theme_is_complete(&theme)
}

style_for_section :: proc(theme: ^Theme, section: string) -> (^tui.Style, bool) {
	switch section {
	case "screen":
		return &theme.screen, true
	case "panel_border_active":
		return &theme.panel_border_active, true
	case "panel_border_inactive":
		return &theme.panel_border_inactive, true
	case "panel_row_active":
		return &theme.panel_row_active, true
	case "panel_row_inactive":
		return &theme.panel_row_inactive, true
	case "selection_active":
		return &theme.selection_active, true
	case "selection_inactive":
		return &theme.selection_inactive, true
	case "status":
		return &theme.status, true
	case "keys":
		return &theme.keys, true
	case "dialog_surface":
		return &theme.dialog_surface, true
	case "dialog_border":
		return &theme.dialog_border, true
	case "dialog_accent":
		return &theme.dialog_accent, true
	case "dialog_action":
		return &theme.dialog_action, true
	case "progress_track":
		return &theme.progress_track, true
	case "progress_fill":
		return &theme.progress_fill, true
	}
	return nil, false
}

apply_style_value :: proc(style: ^tui.Style, key, value: string) -> bool {
	switch key {
	case "foreground", "background":
		text, ok := parse_quoted(value)
		if !ok {
			return false
		}
		color: tui.RGB_Color
		color, ok = parse_hex_color(text)
		if !ok {
			return false
		}
		if key == "foreground" {
			style.foreground_rgb = color
		} else {
			style.background_rgb = color
		}
		return true
	case "bold", "dim", "underline":
		enabled, ok := strconv.parse_bool(value)
		if !ok {
			return false
		}
		if !enabled {
			return true
		}
		switch key {
		case "bold":
			style.attributes += {.Bold}
		case "dim":
			style.attributes += {.Dim}
		case "underline":
			style.attributes += {.Underline}
		}
		return true
	}
	return false
}

parse_quoted :: proc(value: string) -> (string, bool) {
	if len(value) < 2 || value[0] != '"' || value[len(value) - 1] != '"' {
		return "", false
	}
	return value[1:len(value) - 1], true
}

parse_hex_color :: proc(value: string) -> (tui.RGB_Color, bool) {
	if len(value) != 7 || value[0] != '#' {
		return {}, false
	}
	parsed, ok := strconv.parse_u64_of_base(value[1:], 16)
	if !ok {
		return {}, false
	}
	return tui.rgb(u32(parsed)), true
}

theme_is_complete :: proc(theme: ^Theme) -> bool {
	if theme == nil || len(theme.name) == 0 {
		return false
	}
	styles := []^tui.Style {
		&theme.screen,
		&theme.panel_border_active,
		&theme.panel_border_inactive,
		&theme.panel_row_active,
		&theme.panel_row_inactive,
		&theme.selection_active,
		&theme.selection_inactive,
		&theme.status,
		&theme.keys,
		&theme.dialog_surface,
		&theme.dialog_border,
		&theme.dialog_accent,
		&theme.dialog_action,
	}
	for style in styles {
		if !style.foreground_rgb.valid || !style.background_rgb.valid {
			return false
		}
	}
	return theme.progress_track.background_rgb.valid && theme.progress_fill.background_rgb.valid
}
