package commander

import "core:strings"
import "tc:internal/tui"

Dialog_Text_Role :: enum {
	Body,
	Accent,
	Action,
}

Dialog_Template :: struct {
	buffer: ^tui.Buffer,
	rect:   tui.Rect,
	theme:  Theme,
}

dialog_open :: proc(
	buffer: ^tui.Buffer,
	screen_width, screen_height, height: int,
	title: string,
	theme: Theme,
	max_width := 60,
) -> Dialog_Template {
	// Przygaszenie istniejącej zawartości oddziela modal od obu paneli bez
	// polegania na konkretnym odwzorowaniu kolorów ANSI przez terminal.
	for y in 0 ..< screen_height {
		for x in 0 ..< screen_width {
			cell := tui.buffer_get(buffer, x, y)
			cell.style.attributes += {.Dim}
			tui.buffer_set(buffer, x, y, cell)
		}
	}

	dialog_width := min(max_width, screen_width - 4)
	rect := tui.Rect {
		x      = (screen_width - dialog_width) / 2,
		y      = (screen_height - height) / 2,
		width  = dialog_width,
		height = height,
	}
	tui.buffer_fill(buffer, rect, tui.Cell{character = ' ', style = theme.dialog_surface})
	draw_box(buffer, rect, theme.dialog_border)
	tui.buffer_write(buffer, rect.x + 2, rect.y, " ", theme.dialog_border, rect.width - 4)
	tui.buffer_write(buffer, rect.x + 3, rect.y, title, theme.dialog_border, rect.width - 6)
	return Dialog_Template{buffer = buffer, rect = rect, theme = theme}
}

dialog_write :: proc(
	dialog: Dialog_Template,
	row: int,
	text: string,
	role := Dialog_Text_Role.Body,
) {
	rendered := text
	formatted := ""
	if role == .Action {
		formatted = format_action_hints(text)
		rendered = formatted
	}
	defer delete(formatted)
	style := dialog.theme.dialog_surface
	switch role {
	case .Accent:
		style = dialog.theme.dialog_accent
	case .Action:
		style = dialog.theme.dialog_action
	case .Body:
	}
	tui.buffer_write(
		dialog.buffer,
		dialog.rect.x + 3,
		dialog.rect.y + row,
		rendered,
		style,
		dialog.rect.width - 6,
	)
}

format_action_hints :: proc(text: string) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	remaining := strings.trim_space(text)
	first := true
	for part in strings.split_iterator(&remaining, "  ") {
		trimmed_part := strings.trim_space(part)
		if len(trimmed_part) == 0 do continue
		if !first do strings.write_string(&builder, "  ")
		first = false
		space := strings.index_byte(trimmed_part, ' ')
		if space < 0 {
			strings.write_string(&builder, trimmed_part)
			continue
		}
		strings.write_string(&builder, "[")
		strings.write_string(&builder, trimmed_part[:space])
		strings.write_string(&builder, "] ")
		strings.write_string(&builder, trimmed_part[space + 1:])
	}
	return strings.clone(strings.to_string(builder)) or_else ""
}

dialog_progress :: proc(dialog: Dialog_Template, row, percent: int) {
	bar := tui.Rect {
		x      = dialog.rect.x + 3,
		y      = dialog.rect.y + row,
		width  = dialog.rect.width - 6,
		height = 1,
	}
	tui.buffer_fill(
		dialog.buffer,
		bar,
		tui.Cell{character = ' ', style = dialog.theme.progress_track},
	)
	filled := bar.width * clamp(percent, 0, 100) / 100
	tui.buffer_fill(
		dialog.buffer,
		tui.Rect{x = bar.x, y = bar.y, width = filled, height = 1},
		tui.Cell{character = ' ', style = dialog.theme.progress_fill},
	)
}
