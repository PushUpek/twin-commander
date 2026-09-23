package commander

import "core:os"
import "core:strings"
import "core:unicode/utf8"
import "tc:pkg/tui"

Name_Edit_Action :: enum {
	None,
	Submit,
	Cancel,
}

handle_name_edit_input :: proc(name: ^string, cursor: ^int, event: tui.Event, allow_separator := false) -> Name_Edit_Action {
	if event.kind == .Key {
		#partial switch event.key {
		case .Escape:
			return .Cancel
		case .Enter:
			return .Submit
		case .Backspace:
			if cursor^ > 0 {
				_, width := utf8.decode_last_rune(name^[:cursor^])
				replace_edit_name(name, name^[:cursor^ - width], name^[cursor^:])
				cursor^ -= width
			}
		case .Left:
			if cursor^ > 0 {
				_, width := utf8.decode_last_rune(name^[:cursor^])
				cursor^ -= width
			}
		case .Right:
			if cursor^ < len(name^) {
				_, width := utf8.decode_rune_in_string(name^[cursor^:])
				cursor^ += width
			}
		case .Home:
			cursor^ = 0
		case .End:
			cursor^ = len(name^)
		case:
		}
		return .None
	}
	if event.kind == .Text && event.text >= ' ' && (allow_separator || event.text != rune(os.Path_Separator)) {
		encoded, width := utf8.encode_rune(event.text)
		inserted := string(encoded[:width])
		replace_edit_name(name, name^[:cursor^], inserted, name^[cursor^:])
		cursor^ += width
	}
	return .None
}

replace_edit_name :: proc(name: ^string, parts: ..string) {
	new_name := strings.concatenate(parts[:])
	delete(name^)
	name^ = new_name
}

clear_edit_name :: proc(name: ^string, cursor: ^int) {
	delete(name^)
	name^ = ""
	cursor^ = 0
}

target_name_is_valid :: proc(name: string) -> bool {
	return len(name) > 0 && name != "." && name != ".." && !strings.contains_rune(name, rune(os.Path_Separator))
}

invalid_target_name_status :: proc() -> string {
	return strings.clone(tr("Podaj poprawną nazwę bez separatora katalogów")) or_else ""
}
