package commander

import "core:encoding/json"
import "core:strings"
import "tc:pkg/tui"

viewer_pretty_json :: proc(data: []byte) -> ([]byte, bool) {
	parsed, err := json.parse(data)
	if err != nil do return nil, false
	defer json.destroy_value(parsed)

	output := strings.builder_make()
	defer strings.builder_destroy(&output)
	depth := 0
	in_string := false
	escaped := false
	last: byte
	for ch, index in data {
		if in_string {
			strings.write_byte(&output, ch)
			if escaped {
				escaped = false
			} else if ch == '\\' {
				escaped = true
			} else if ch == '"' {
				in_string = false
			}
			last = ch
			continue
		}
		if ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' do continue
		switch ch {
		case '"':
			in_string = true
			strings.write_byte(&output, ch)
		case '{', '[':
			strings.write_byte(&output, ch)
			depth += 1
			next := index + 1
			for next < len(data) && (data[next] == ' ' || data[next] == '\t' || data[next] == '\r' || data[next] == '\n') do next += 1
			if next < len(data) && data[next] != '}' && data[next] != ']' do viewer_json_newline(&output, depth)
		case '}', ']':
			depth = max(depth - 1, 0)
			if last != '{' && last != '[' do viewer_json_newline(&output, depth)
			strings.write_byte(&output, ch)
		case ',':
			strings.write_byte(&output, ch)
			viewer_json_newline(&output, depth)
		case ':':
			strings.write_string(&output, ": ")
		case:
			strings.write_byte(&output, ch)
		}
		last = ch
	}
	strings.write_byte(&output, '\n')
	formatted := strings.clone(strings.to_string(output)) or_else ""
	if len(formatted) == 0 do return nil, false
	return transmute([]byte)formatted, true
}

viewer_json_newline :: proc(output: ^strings.Builder, depth: int) {
	strings.write_byte(output, '\n')
	for _ in 0 ..< depth do strings.write_string(output, "  ")
}

viewer_draw_json_line :: proc(buffer: ^tui.Buffer, x, y: int, line: string, max_width: int, theme: Theme) {
	cursor := x
	limit := x + max_width
	index := 0
	for index < len(line) && cursor < limit {
		start := index
		style := theme.dialog_surface
		ch := line[index]
		if ch == '"' {
			index += 1
			escaped := false
			for index < len(line) {
				current := line[index]
				index += 1
				if escaped {
					escaped = false
				} else if current == '\\' {
					escaped = true
				} else if current == '"' {
					break
				}
			}
			lookahead := index
			for lookahead < len(line) && (line[lookahead] == ' ' || line[lookahead] == '\t') do lookahead += 1
			style = theme.viewer_json_string
			if lookahead < len(line) && line[lookahead] == ':' do style = theme.viewer_json_key
		} else if ch >= '0' && ch <= '9' || ch == '-' {
			index += 1
			for index < len(line) && viewer_json_number_byte(line[index]) do index += 1
			style = theme.viewer_json_number
		} else if ch == 't' || ch == 'f' || ch == 'n' {
			index += 1
			for index < len(line) && line[index] >= 'a' && line[index] <= 'z' do index += 1
			style = theme.viewer_json_literal
		} else {
			index += 1
			if ch == '{' || ch == '}' || ch == '[' || ch == ']' || ch == ',' || ch == ':' {
				style = theme.viewer_json_punctuation
			}
		}
		cursor += tui.buffer_write(buffer, cursor, y, line[start:index], style, limit - cursor)
	}
}

viewer_json_number_byte :: proc(ch: byte) -> bool {
	return ch >= '0' && ch <= '9' || ch == '.' || ch == '-' || ch == '+' || ch == 'e' || ch == 'E'
}
