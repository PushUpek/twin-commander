package tui_terminal

import "core:testing"

@(test)
osc_11_classifies_dark_and_light_backgrounds :: proc(t: ^testing.T) {
	dark := session_with_pending("\e]11;rgb:1111/2222/3333\e\\")
	event, ok := parse_pending(&dark)
	testing.expect(t, ok)
	testing.expect_value(t, event.kind, Event_Kind.Appearance)
	testing.expect_value(t, event.appearance, Appearance.Dark)
	testing.expect_value(t, event.appearance_source, Appearance_Source.Background)
	testing.expect_value(t, dark.pending_count, 0)

	light := session_with_pending("\e]11;rgb:eeee/ffff/dddd\a")
	event, ok = parse_pending(&light)
	testing.expect(t, ok)
	testing.expect_value(t, event.kind, Event_Kind.Appearance)
	testing.expect_value(t, event.appearance, Appearance.Light)
	testing.expect_value(t, light.pending_count, 0)
}

@(test)
color_scheme_preference_reports_are_parsed :: proc(t: ^testing.T) {
	unknown := session_with_pending("\e[?997;0n")
	event, ok := parse_pending(&unknown)
	testing.expect(t, ok)
	testing.expect_value(t, event.kind, Event_Kind.Appearance)
	testing.expect_value(t, event.appearance, Appearance.Unknown)
	testing.expect_value(t, event.appearance_source, Appearance_Source.Preference)
	testing.expect_value(t, unknown.pending_count, 0)

	dark := session_with_pending("\e[?997;1n")
	event, ok = parse_pending(&dark)
	testing.expect(t, ok)
	testing.expect_value(t, event.appearance, Appearance.Dark)
	testing.expect_value(t, event.appearance_source, Appearance_Source.Preference)

	light := session_with_pending("\e[?997;2n")
	event, ok = parse_pending(&light)
	testing.expect(t, ok)
	testing.expect_value(t, event.appearance, Appearance.Light)
	testing.expect_value(t, event.appearance_source, Appearance_Source.Preference)
}

@(test)
incomplete_osc_response_remains_buffered :: proc(t: ^testing.T) {
	session := session_with_pending("\e]11;rgb:ffff/ffff")
	_, ok := parse_pending(&session)
	testing.expect(t, !ok)
	testing.expect_value(t, session.pending_count, len("\e]11;rgb:ffff/ffff"))

	rest: string = "/ffff\e\\"
	rest_bytes := transmute([]u8)rest
	copy(session.pending[session.pending_count:], rest_bytes)
	session.pending_count += len(rest_bytes)
	event: Event
	event, ok = parse_pending(&session)
	testing.expect(t, ok)
	testing.expect_value(t, event.appearance, Appearance.Light)
	testing.expect_value(t, session.pending_count, 0)
}

session_with_pending :: proc(value: string) -> Session {
	session: Session
	bytes := transmute([]u8)value
	copy(session.pending[:], bytes)
	session.pending_count = len(bytes)
	return session
}

@(test)
function_keys_support_ss3_and_csi_terminal_encodings :: proc(t: ^testing.T) {
	for item in ([]struct {sequence: string, key: Key}{
		{"\eOR", .F3}, {"\eOS", .F4},
		{"\e[13~", .F3}, {"\e[14~", .F4},
		{"\e[[C", .F3}, {"\e[[D", .F4},
		{"\e[1;2R", .F3}, {"\e[1;2S", .F4},
		{"\e[1;5R", .F3}, {"\e[1;5S", .F4},
	}) {
		session := session_with_pending(item.sequence)
		event, ok := parse_pending(&session)
		testing.expect(t, ok)
		testing.expect_value(t, event.kind, Event_Kind.Key)
		testing.expect_value(t, event.key, item.key)
		testing.expect_value(t, session.pending_count, 0)
	}
}
