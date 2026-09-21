package commander

import "core:testing"
import "tc:internal/tui"

@(test)
only_f10_requires_confirmation_before_exit :: proc(t: ^testing.T) {
	app: App_State
	running := true

	handle_event(nil, &app, tui.Event{kind = .Key, key = .Escape}, &running)
	testing.expect(t, running)
	testing.expect(t, !app.exit_pending)

	handle_event(nil, &app, tui.Event{kind = .Key, key = .F10}, &running)
	testing.expect(t, running)
	testing.expect(t, app.exit_pending)

	handle_event(nil, &app, tui.Event{kind = .Key, key = .Escape}, &running)
	testing.expect(t, running)
	testing.expect(t, !app.exit_pending)

	handle_event(nil, &app, tui.Event{kind = .Key, key = .F10}, &running)
	handle_event(nil, &app, tui.Event{kind = .Key, key = .Enter}, &running)
	testing.expect(t, !running)
	testing.expect(t, !app.exit_pending)
}

@(test)
exit_confirmation_supports_text_choices :: proc(t: ^testing.T) {
	app := App_State {
		exit_pending = true,
	}
	running := true

	handle_event(nil, &app, tui.Event{kind = .Text, text = 'n'}, &running)
	if !testing.expect(t, running && !app.exit_pending) do return

	app.exit_pending = true
	handle_event(nil, &app, tui.Event{kind = .Text, text = 'T'}, &running)
	testing.expect(t, !running && !app.exit_pending)
}

@(test)
exit_dialog_contains_question_and_actions :: proc(t: ^testing.T) {
	buffer: tui.Buffer
	tui.buffer_init(&buffer, 80, 24)
	defer tui.buffer_destroy(&buffer)

	theme := theme_for(.Dark)
	defer destroy_theme(&theme)
	draw_exit_dialog(&buffer, 80, 24, theme)

	testing.expect_value(t, tui.buffer_get(&buffer, 10, 9).character, rune('┌'))
	testing.expect_value(t, tui.buffer_get(&buffer, 13, 11).character, rune('C'))
	testing.expect_value(t, tui.buffer_get(&buffer, 14, 13).character, rune('E'))
	testing.expect(t, .Dim in tui.buffer_get(&buffer, 0, 0).style.attributes)
}
