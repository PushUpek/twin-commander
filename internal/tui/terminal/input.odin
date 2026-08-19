package tui_terminal

import "core:bytes"
import "core:strconv"
import "core:unicode/utf8"

parse_pending :: proc(session: ^Session) -> (Event, bool) {
	if session.pending_count == 0 {
		return {}, false
	}

	data := session.pending[:session.pending_count]
	first := data[0]

	if len(data) >= 3 && first == 0x1b && data[1] == '[' && data[2] == '?' {
		event, consumed, recognized, complete := parse_appearance_report(data)
		if !recognized {
			// Continue with regular escape-sequence parsing.
		} else if !complete {
			previous_count := session.pending_count
			read_pending(session, 8)
			if session.pending_count > previous_count {
				return parse_pending(session)
			}
			return {}, false
		} else {
			consume_pending(session, consumed)
			return event, true
		}
	}

	if first == 0x1b && len(data) >= 2 && data[1] == ']' {
		event, consumed, complete := parse_osc(data)
		if !complete {
			previous_count := session.pending_count
			read_pending(session, 8)
			if session.pending_count > previous_count {
				return parse_pending(session)
			}
			return {}, false
		}
		consume_pending(session, consumed)
		return event, event.kind != .None
	}

	if first == 0x1b {
		if event, consumed, ok := parse_escape(data); ok {
			consume_pending(session, consumed)
			return event, true
		}

		// Give a terminal a brief chance to finish a split escape sequence.
		if session.pending_count == 1 && read_pending(session, 8) {
			return parse_pending(session)
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
		return Event{kind = .Text, text = rune('a' + first - 1), modifiers = {.Control}}, true
	}

	decoded, width := utf8.decode_rune(data)
	if width <= 0 || width > session.pending_count {
		return {}, false
	}
	consume_pending(session, width)
	return Event{kind = .Text, text = decoded}, true
}

parse_appearance_report :: proc(data: []u8) -> (Event, int, bool, bool) {
	reports := []struct {
		sequence:   string,
		appearance: Appearance,
	} {
		{"\e[?997;0n", .Unknown},
		{"\e[?997;1n", .Dark},
		{"\e[?997;2n", .Light},
	}
	for report in reports {
		sequence := transmute([]u8)report.sequence
		prefix_width := min(len(data), len(sequence))
		if bytes.equal(data[:prefix_width], sequence[:prefix_width]) {
			if len(data) < len(sequence) {
				return {}, 0, true, false
			}
			return Event {
					kind = .Appearance,
					appearance = report.appearance,
					appearance_source = .Preference,
				},
				len(sequence),
				true,
				true
		}
	}
	return {}, 0, false, false
}

parse_osc :: proc(data: []u8) -> (Event, int, bool) {
	end := -1
	terminator_width := 0
	for index in 2 ..< len(data) {
		if data[index] == 0x07 {
			end = index
			terminator_width = 1
			break
		}
		if data[index] == 0x1b && index + 1 < len(data) && data[index + 1] == '\\' {
			end = index
			terminator_width = 2
			break
		}
	}
	if end < 0 {
		return {}, 0, false
	}

	prefix_text: string = "\e]11;"
	prefix := transmute([]u8)prefix_text
	if end > len(prefix) && len(data) >= len(prefix) && bytes.equal(data[:len(prefix)], prefix) {
		if appearance, ok := appearance_from_color(data[len(prefix):end]); ok {
			return Event {
					kind = .Appearance,
					appearance = appearance,
					appearance_source = .Background,
				},
				end + terminator_width,
				true
		}
	}
	return {}, end + terminator_width, true
}

appearance_from_color :: proc(value: []u8) -> (Appearance, bool) {
	r, g, b: int
	rgb_prefix_text: string = "rgb:"
	rgb_prefix := transmute([]u8)rgb_prefix_text
	if len(value) >= 4 && bytes.equal(value[:4], rgb_prefix) {
		index := 4
		ok: bool
		r, index, ok = parse_color_channel(value, index, '/')
		if !ok do return {}, false
		g, index, ok = parse_color_channel(value, index, '/')
		if !ok do return {}, false
		b, index, ok = parse_color_channel(value, index, 0)
		if !ok || index != len(value) do return {}, false
	} else if len(value) > 1 && value[0] == '#' && (len(value) - 1) % 3 == 0 {
		width := (len(value) - 1) / 3
		if width < 1 || width > 4 do return {}, false
		ok: bool
		r, ok = scaled_hex(value[1:1 + width])
		if !ok do return {}, false
		g, ok = scaled_hex(value[1 + width:1 + 2 * width])
		if !ok do return {}, false
		b, ok = scaled_hex(value[1 + 2 * width:])
		if !ok do return {}, false
	} else {
		return {}, false
	}

	brightness := (299 * r + 587 * g + 114 * b) / 1000
	if brightness >= 128 {
		return .Light, true
	}
	return .Dark, true
}

parse_color_channel :: proc(value: []u8, start: int, separator: u8) -> (int, int, bool) {
	end := start
	for end < len(value) && value[end] != separator {
		end += 1
	}
	if end == start || end - start > 4 || (separator != 0 && end == len(value)) {
		return 0, start, false
	}
	channel, ok := scaled_hex(value[start:end])
	if !ok do return 0, start, false
	if separator != 0 do end += 1
	return channel, end, true
}

scaled_hex :: proc(value: []u8) -> (int, bool) {
	parsed, ok := strconv.parse_u64_of_base(string(value), 16)
	if !ok || len(value) < 1 || len(value) > 4 {
		return 0, false
	}
	maximum := u64(1) << u64(4 * len(value))
	maximum -= 1
	return int(parsed * 255 / maximum), true
}

parse_escape :: proc(data: []u8) -> (Event, int, bool) {
	sequences := []struct {
		sequence: string,
		key:      Key,
	} {
		{"\e[A", .Up},
		{"\e[B", .Down},
		{"\e[C", .Right},
		{"\e[D", .Left},
		{"\e[H", .Home},
		{"\e[F", .End},
		{"\e[1~", .Home},
		{"\e[4~", .End},
		{"\e[5~", .Page_Up},
		{"\e[6~", .Page_Down},
		{"\eOP", .F1},
		{"\eOQ", .F2},
		{"\eOR", .F3},
		{"\eOS", .F4},
		{"\e[15~", .F5},
		{"\e[17~", .F6},
		{"\e[18~", .F7},
		{"\e[19~", .F8},
		{"\e[20~", .F9},
		{"\e[21~", .F10},
		{"\e[23~", .F11},
		{"\e[24~", .F12},
	}

	for item in sequences {
		sequence_bytes := transmute([]u8)item.sequence
		if len(data) >= len(sequence_bytes) &&
		   bytes.equal(data[:len(sequence_bytes)], sequence_bytes) {
			return Event{kind = .Key, key = item.key}, len(sequence_bytes), true
		}
	}

	return {}, 0, false
}
