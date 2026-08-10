package main

import "core:fmt"
import "./tui"

Panel_State :: struct {
	selected: int,
}

FILES := [2][]string{
	{"..", "Dokumenty", "Zdjęcia", "projekty", "README.md", "notatki.txt"},
	{"..", "Downloads", "Muzyka", "archiwum.zip", "raport.pdf", "todo.md"},
}

main :: proc() {
	ui_context: tui.Context
	if !tui.init(&ui_context) {
		fmt.eprintln("Twin Commander wymaga interaktywnego terminala POSIX")
		return
	}
	defer tui.destroy(&ui_context)

	panels: [2]Panel_State
	active_panel := 0
	running := true

	for running {
		draw(&ui_context, panels[:], active_panel)
		if !tui.present(&ui_context) {
			break
		}

		event, ok := tui.poll_event(&ui_context)
		if !ok {
			continue
		}

		#partial switch event.kind {
		case .Key:
			#partial switch event.key {
			case .Escape:
				running = false
			case .Tab:
				active_panel = 1-active_panel
			case .Up:
				panels[active_panel].selected = max(panels[active_panel].selected-1, 0)
			case .Down:
				last := len(FILES[active_panel])-1
				panels[active_panel].selected = min(panels[active_panel].selected+1, last)
			}
		case .Text:
			if .Control in event.modifiers && event.text == 'c' {
				running = false
			}
		}
	}
}

draw :: proc(ctx: ^tui.Context, panels: []Panel_State, active_panel: int) {
	buffer := tui.begin_frame(ctx)
	width, height := tui.size(ctx)
	if width < 20 || height < 8 {
		tui.buffer_write(buffer, 0, 0, "Terminal jest zbyt mały", tui.Style{foreground = .Yellow})
		return
	}

	footer_height := 2
	left_width := width/2
	panel_height := height-footer_height
	draw_panel(buffer, tui.Rect{x = 0, y = 0, width = left_width, height = panel_height}, "Lewy panel", FILES[0], panels[0], active_panel == 0)
	draw_panel(buffer, tui.Rect{x = left_width, y = 0, width = width-left_width, height = panel_height}, "Prawy panel", FILES[1], panels[1], active_panel == 1)

	status_style := tui.Style{foreground = .Black, background = .Cyan}
	tui.buffer_fill(buffer, tui.Rect{x = 0, y = height-2, width = width, height = 1}, tui.Cell{character = ' ', style = status_style})
	tui.buffer_write(buffer, 1, height-2, "Tab: panel   ↑/↓: wybór   Esc/Ctrl-C: wyjście", status_style, width-2)

	keys_style := tui.Style{foreground = .Black, background = .White}
	tui.buffer_fill(buffer, tui.Rect{x = 0, y = height-1, width = width, height = 1}, tui.Cell{character = ' ', style = keys_style})
	tui.buffer_write(buffer, 0, height-1, "1Pomoc  2Menu  3Podgląd  4Edycja  5Kopiuj  6Przenieś  7Katalog  8Usuń  10Koniec", keys_style, width)
}

draw_panel :: proc(buffer: ^tui.Buffer, rect: tui.Rect, title: string, files: []string, state: Panel_State, active: bool) {
	border_style := tui.Style{foreground = .Cyan}
	if active {
		border_style = tui.Style{foreground = .White, attributes = {.Bold}}
	}
	draw_box(buffer, rect, border_style)
	tui.buffer_set(buffer, rect.x+1, rect.y, tui.Cell{character = ' ', style = border_style})
	title_width := tui.buffer_write(buffer, rect.x+2, rect.y, title, border_style, rect.width-4)
	tui.buffer_set(buffer, rect.x+2+title_width, rect.y, tui.Cell{character = ' ', style = border_style})

	visible_rows := max(rect.height-2, 0)
	for index in 0..<min(len(files), visible_rows) {
		row_style := tui.Style{}
		if index == state.selected {
			row_style = tui.Style{foreground = .Black, background = .Cyan}
		}
		tui.buffer_fill(buffer, tui.Rect{x = rect.x+1, y = rect.y+1+index, width = rect.width-2, height = 1}, tui.Cell{character = ' ', style = row_style})
		tui.buffer_write(buffer, rect.x+2, rect.y+1+index, files[index], row_style, rect.width-4)
	}
}

draw_box :: proc(buffer: ^tui.Buffer, rect: tui.Rect, style: tui.Style) {
	if rect.width < 2 || rect.height < 2 {
		return
	}
	left, right := rect.x, rect.x+rect.width-1
	top, bottom := rect.y, rect.y+rect.height-1
	tui.buffer_set(buffer, left, top, tui.Cell{character = '┌', style = style})
	tui.buffer_set(buffer, right, top, tui.Cell{character = '┐', style = style})
	tui.buffer_set(buffer, left, bottom, tui.Cell{character = '└', style = style})
	tui.buffer_set(buffer, right, bottom, tui.Cell{character = '┘', style = style})
	for x in left+1..<right {
		tui.buffer_set(buffer, x, top, tui.Cell{character = '─', style = style})
		tui.buffer_set(buffer, x, bottom, tui.Cell{character = '─', style = style})
	}
	for y in top+1..<bottom {
		tui.buffer_set(buffer, left, y, tui.Cell{character = '│', style = style})
		tui.buffer_set(buffer, right, y, tui.Cell{character = '│', style = style})
	}
}
