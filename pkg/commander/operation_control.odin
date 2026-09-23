package commander

import "core:os"
import "tc:pkg/tui"

Operation_Error_Choice :: enum {
	Abort,
	Retry,
	Skip,
}

ask_operation_error :: proc(
	ctx: ^tui.Context,
	app: ^App_State,
	entry_name: string,
	err: os.Error,
) -> Operation_Error_Choice {
	if ctx == nil do return .Abort
	for {
		draw(ctx, app)
		buffer := tui.current_buffer(ctx)
		width, height := tui.size(ctx)
		draw_operation_error_dialog(buffer, width, height, entry_name, os.error_string(err), app.theme)
		if !tui.present(ctx) do return .Abort
		event, ok := tui.poll_event(ctx)
		if !ok do continue
		if event.kind == .Key && event.key == .Escape do return .Abort
		if event.kind == .Text {
			switch event.text {
			case 'r', 'R': return .Retry
			case 'p', 'P': return .Skip
			case 'a', 'A': return .Abort
			}
		}
	}
}

operation_cancel_requested :: proc(ctx: ^tui.Context) -> bool {
	if ctx == nil do return false
	event, ok := tui.poll_event(ctx, 0)
	if !ok do return false
	if event.kind == .Key && event.key == .Escape do return true
	return event.kind == .Text && .Control in event.modifiers && event.text == 'c'
}
