package tui_terminal

import "core:c"

when ODIN_OS == .Darwin {
	foreign import libc "system:System"
} else {
	foreign import libc "system:c"
}

Winsize :: struct {
	rows:    u16,
	columns: u16,
	xpixel:  u16,
	ypixel:  u16,
}

foreign libc {
	ioctl :: proc(fd: c.int, request: c.ulong, #c_vararg arguments: ..any) -> c.int ---
}

when ODIN_OS == .Darwin || ODIN_OS == .FreeBSD || ODIN_OS == .NetBSD || ODIN_OS == .OpenBSD {
	TIOCGWINSZ :: c.ulong(0x40087468)
} else when ODIN_OS == .Linux {
	TIOCGWINSZ :: c.ulong(0x5413)
}

get_size :: proc() -> (Size, bool) {
	if result, ok := get_size_for_fd(STDOUT); ok {
		return result, true
	}
	return get_size_for_fd(STDIN)
}

get_size_for_fd :: proc(fd: posix.FD) -> (Size, bool) {
	winsize: Winsize
	if ioctl(c.int(fd), TIOCGWINSZ, &winsize) != 0 || winsize.columns == 0 || winsize.rows == 0 {
		return {}, false
	}
	return Size{width = int(winsize.columns), height = int(winsize.rows)}, true
}

import "core:sys/posix"
