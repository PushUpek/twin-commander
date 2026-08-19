package tui

import term "./terminal"
import "core:strings"

Event :: term.Event
Event_Kind :: term.Event_Kind
Key :: term.Key
Appearance :: term.Appearance

Context :: struct {
	terminal: term.Session,
	screen:   Screen,
}

init :: proc(tui: ^Context) -> bool {
	if tui == nil || !term.open(&tui.terminal) {
		return false
	}
	screen_init(&tui.screen, tui.terminal.size.width, tui.terminal.size.height)
	return true
}

destroy :: proc(tui: ^Context) {
	if tui == nil {
		return
	}
	screen_destroy(&tui.screen)
	term.close(&tui.terminal)
}

suspend :: proc(tui: ^Context) {
	if tui == nil {
		return
	}
	term.close(&tui.terminal)
}

resume :: proc(tui: ^Context) -> bool {
	if tui == nil || !term.open(&tui.terminal) {
		return false
	}
	width, height := term.current_size(&tui.terminal)
	screen_resize(&tui.screen, width, height)
	tui.screen.force_redraw = true
	return true
}

size :: proc(tui: ^Context) -> (width, height: int) {
	return tui.screen.back.width, tui.screen.back.height
}

begin_frame :: proc(tui: ^Context) -> ^Buffer {
	return screen_begin(&tui.screen)
}

present :: proc(tui: ^Context) -> bool {
	output := screen_render(&tui.screen)
	defer strings.builder_destroy(&output)
	return term.write(strings.to_string(output))
}

poll_event :: proc(tui: ^Context, timeout_ms := -1) -> (Event, bool) {
	event, ok := term.poll_event(&tui.terminal, timeout_ms)
	if ok && event.kind == .Resize {
		screen_resize(&tui.screen, event.size.width, event.size.height)
	}
	return event, ok
}
