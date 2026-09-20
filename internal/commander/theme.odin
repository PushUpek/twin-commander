package commander

import "base:runtime"
import "core:os"
import "core:fmt"
import "core:strings"
import themes "./themes"

Theme_Mode :: themes.Mode
Theme :: themes.Theme

load_theme :: proc(mode: Theme_Mode, allocator: runtime.Allocator) -> (Theme, bool) {
	base: Theme
	ok: bool
	switch mode {
	case .Light:
		base, ok = themes.light_kanso_pearl(allocator)
	case .Dark:
		base, ok = themes.dark_kanso_mist(allocator)
	}
	if !ok { return {}, false }
	variable := "TWIN_COMMANDER_DARK_THEME"
	if mode == .Light { variable = "TWIN_COMMANDER_LIGHT_THEME" }
	path := os.get_env(variable, context.temp_allocator)
	if len(path) == 0 { return base, true }
	custom, custom_ok := themes.load_theme_file(path, allocator, base)
	if !custom_ok {
		fmt.eprintf("Invalid theme file %s; using Kanso default\n", path)
		return base, true
	}
	themes.theme_destroy(&base)
	return custom, true
}

theme_for :: proc(mode: Theme_Mode) -> Theme {
	theme, ok := load_theme(mode, context.allocator)
	assert(ok, "Nie można wczytać motywu z config/themes")
	return theme
}

destroy_theme :: proc(theme: ^Theme) {
	themes.theme_destroy(theme)
}

system_theme_mode :: proc() -> (Theme_Mode, bool) {
	when ODIN_OS == .Darwin {
		state, stdout, stderr, err := os.process_exec(
			os.Process_Desc{command = []string{"/usr/bin/defaults", "read", "-g", "AppleInterfaceStyle"}},
			context.temp_allocator,
		)
		_ = stderr
		if err != nil {
			return {}, false
		}
		return theme_mode_from_apple_style(string(stdout), state.success)
	}
	return {}, false
}

theme_mode_from_apple_style :: proc(value: string, key_exists: bool) -> (Theme_Mode, bool) {
	if !key_exists {
		// macOS nie zapisuje klucza AppleInterfaceStyle dla trybu jasnego.
		return .Light, true
	}
	if strings.contains(value, "Dark") {
		return .Dark, true
	}
	return {}, false
}

theme_mode_override :: proc() -> (Theme_Mode, bool) {
	value := os.get_env("TWIN_COMMANDER_THEME", context.temp_allocator)
	switch value {
	case "light", "LIGHT", "Light":
		return .Light, true
	case "dark", "DARK", "Dark":
		return .Dark, true
	}
	return {}, false
}
