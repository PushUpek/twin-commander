package commander_themes

import "base:runtime"

LIGHT_KANSO_PEARL_PATH :: "config/themes/light_kanso_pearl.toml"

light_kanso_pearl :: proc(allocator: runtime.Allocator) -> (Theme, bool) {
	return load_theme_file(LIGHT_KANSO_PEARL_PATH, allocator)
}
