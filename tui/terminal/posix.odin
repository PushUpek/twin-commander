package tui_terminal

import "core:c"

foreign import libc "system:c"

Winsize :: struct {
	rows:    u16,
	columns: u16,
	xpixel:  u16,
	ypixel:  u16,
}

foreign libc {
	ioctl :: proc(fd: c.int, request: c.ulong, argument: rawptr) -> c.int ---
}

when ODIN_OS == .Darwin || ODIN_OS == .FreeBSD || ODIN_OS == .NetBSD || ODIN_OS == .OpenBSD {
	TIOCGWINSZ :: c.ulong(0x40087468)
} else when ODIN_OS == .Linux {
	TIOCGWINSZ :: c.ulong(0x5413)
}

get_size :: proc() -> Size {
	result := Size{width = 80, height = 24}
	winsize: Winsize
	if ioctl(c.int(STDOUT), TIOCGWINSZ, &winsize) == 0 {
		if winsize.columns > 0 {
			result.width = int(winsize.columns)
		}
		if winsize.rows > 0 {
			result.height = int(winsize.rows)
		}
	}
	return result
}
