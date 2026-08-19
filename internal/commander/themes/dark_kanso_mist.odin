package commander_themes

import "base:runtime"

DARK_KANSO_MIST_PATH :: "config/themes/dark_kanso_mist.toml"

dark_kanso_mist :: proc(allocator: runtime.Allocator) -> (Theme, bool) {
	return load_theme_file(DARK_KANSO_MIST_PATH, allocator)
}
