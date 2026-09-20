package commander_themes

import "base:runtime"
import "core:strings"

DARK_KANSO_MIST_PATH :: "config/themes/dark_kanso_mist.toml"

dark_kanso_mist :: proc(allocator: runtime.Allocator) -> (Theme, bool) {
	theme, ok := parse_theme(#load("../../../config/themes/dark_kanso_mist.toml", string))
	if !ok { return {}, false }
	theme.name = strings.clone(theme.name, allocator) or_else ""
	return theme, len(theme.name) > 0
}
