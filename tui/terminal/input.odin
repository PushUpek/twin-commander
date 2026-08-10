package tui_terminal

import "core:bytes"
import "core:unicode/utf8"

parse_pending :: proc(session: ^Session) -> (Event, bool) {
	if session.pending_count == 0 {
		return {}, false
	}

	data := session.pending[:session.pending_count]
	first := data[0]

	if first == 0x1b {
		if event, consumed, ok := parse_escape(data); ok {
			consume_pending(session, consumed)
			return event, true
		}

		// Give a terminal a brief chance to finish a split escape sequence.
		if session.pending_count == 1 {
			read_pending(session, 8)
			data = session.pending[:session.pending_count]
			if event, consumed, ok := parse_escape(data); ok {
				consume_pending(session, consumed)
				return event, true
			}
		}

		consume_pending(session, 1)
		return Event{kind = .Key, key = .Escape}, true
	}

	switch first {
	case '\r', '\n':
		consume_pending(session, 1)
		return Event{kind = .Key, key = .Enter}, true
	case '\t':
		consume_pending(session, 1)
		return Event{kind = .Key, key = .Tab}, true
	case 0x7f, 0x08:
		consume_pending(session, 1)
		return Event{kind = .Key, key = .Backspace}, true
	}

	if first >= 1 && first <= 26 {
		consume_pending(session, 1)
		return Event{
			kind      = .Text,
			text      = rune('a'+first-1),
			modifiers = {.Control},
		}, true
	}

	decoded, width := utf8.decode_rune(data)
	if width <= 0 || width > session.pending_count {
		return {}, false
	}
	consume_pending(session, width)
	return Event{kind = .Text, text = decoded}, true
}

parse_escape :: proc(data: []u8) -> (Event, int, bool) {
	sequences := []struct {
		sequence: string,
		key:      Key,
	}{
		{"\e[A", .Up}, {"\e[B", .Down}, {"\e[C", .Right}, {"\e[D", .Left},
		{"\e[H", .Home}, {"\e[F", .End}, {"\e[1~", .Home}, {"\e[4~", .End},
		{"\e[5~", .Page_Up}, {"\e[6~", .Page_Down},
		{"\eOP", .F1}, {"\eOQ", .F2}, {"\eOR", .F3}, {"\eOS", .F4},
		{"\e[15~", .F5}, {"\e[17~", .F6}, {"\e[18~", .F7}, {"\e[19~", .F8},
		{"\e[20~", .F9}, {"\e[21~", .F10}, {"\e[23~", .F11}, {"\e[24~", .F12},
	}

	for item in sequences {
		sequence_bytes := transmute([]u8)item.sequence
		if len(data) >= len(sequence_bytes) && bytes.equal(data[:len(sequence_bytes)], sequence_bytes) {
			return Event{kind = .Key, key = item.key}, len(sequence_bytes), true
		}
	}

	return {}, 0, false
}
