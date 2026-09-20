package commander_themes

import "base:runtime"
import "core:strings"

LIGHT_KANSO_PEARL_PATH :: "config/themes/light_kanso_pearl.toml"

light_kanso_pearl :: proc(allocator: runtime.Allocator) -> (Theme, bool) {
	theme, ok := parse_theme(#load("../../../config/themes/light_kanso_pearl.toml", string))
	if !ok { return {}, false }
	theme.name = strings.clone(theme.name, allocator) or_else ""
	return theme, len(theme.name) > 0
}
