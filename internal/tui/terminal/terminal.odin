package tui_terminal

import "core:c"
import "core:sys/posix"

Size :: struct {
	width:  int,
	height: int,
}

Modifiers :: bit_set[Modifier]

Modifier :: enum {
	Shift,
	Alt,
	Control,
}

Key :: enum {
	None,
	Escape,
	Enter,
	Tab,
	Backspace,
	Up,
	Down,
	Left,
	Right,
	Home,
	End,
	Page_Up,
	Page_Down,
	F1,
	F2,
	F3,
	F4,
	F5,
	F6,
	F7,
	F8,
	F9,
	F10,
	F11,
	F12,
}

Event_Kind :: enum {
	None,
	Key,
	Text,
	Resize,
}

Event :: struct {
	kind:      Event_Kind,
	key:       Key,
	text:      rune,
	modifiers: Modifiers,
	size:      Size,
}

Session :: struct {
	original_mode: posix.termios,
	active:        bool,
	size:          Size,
	pending:       [256]u8,
	pending_count: int,
}

STDIN :: posix.FD(0)
STDOUT :: posix.FD(1)

open :: proc(session: ^Session) -> bool {
	if session == nil || posix.tcgetattr(STDIN, &session.original_mode) != .OK {
		return false
	}

	terminal_size, size_ok := get_size()
	if !size_ok {
		return false
	}

	raw := session.original_mode
	raw.c_iflag -= {.BRKINT, .ICRNL, .INPCK, .ISTRIP, .IXON}
	raw.c_oflag -= {.OPOST}
	raw.c_lflag -= {.ECHO, .ICANON, .IEXTEN, .ISIG}
	raw.c_cflag += {.CS8}
	raw.c_cc[.VMIN] = 0
	raw.c_cc[.VTIME] = 1

	if posix.tcsetattr(STDIN, .TCSAFLUSH, &raw) != .OK {
		return false
	}

	session.active = true
	session.size = terminal_size
	write("\e[?1049h\e[?25l\e[2J\e[H")
	return true
}

close :: proc(session: ^Session) {
	if session == nil || !session.active {
		return
	}

	write("\e[0m\e[?25h\e[?1049l")
	posix.tcsetattr(STDIN, .TCSAFLUSH, &session.original_mode)
	session.active = false
}

write :: proc(data: string) -> bool {
	bytes := transmute([]u8)data
	written := 0
	for written < len(bytes) {
		count := posix.write(
			STDOUT,
			raw_data(bytes[written:]),
			c.size_t(int(len(bytes)) - written),
		)
		if count <= 0 {
			return false
		}
		written += int(count)
	}
	return true
}

poll_event :: proc(session: ^Session, timeout_ms: int) -> (Event, bool) {
	if session == nil || !session.active {
		return {}, false
	}

	current_size, size_ok := get_size()
	if size_ok && current_size != session.size {
		session.size = current_size
		return Event{kind = .Resize, size = current_size}, true
	}

	if session.pending_count == 0 && !read_pending(session, timeout_ms) {
		return {}, false
	}

	return parse_pending(session)
}

read_pending :: proc(session: ^Session, timeout_ms: int) -> bool {
	poll_fds := []posix.pollfd{{fd = STDIN, events = {.IN}}}
	ready := posix.poll(raw_data(poll_fds), posix.nfds_t(len(poll_fds)), c.int(timeout_ms))
	if ready <= 0 || poll_fds[0].revents < {.IN} {
		return false
	}

	available := len(session.pending) - session.pending_count
	if available <= 0 {
		return false
	}

	count := posix.read(STDIN, &session.pending[session.pending_count], c.size_t(available))
	if count <= 0 {
		return false
	}
	session.pending_count += int(count)
	return true
}

consume_pending :: proc(session: ^Session, count: int) {
	if count >= session.pending_count {
		session.pending_count = 0
		return
	}
	copy(session.pending[:], session.pending[count:session.pending_count])
	session.pending_count -= count
}
