package commander

import "base:runtime"
import "core:os"
import "core:strings"
import themes "./themes"

Theme_Mode :: themes.Mode
Theme :: themes.Theme

load_theme :: proc(mode: Theme_Mode, allocator: runtime.Allocator) -> (Theme, bool) {
	switch mode {
	case .Light:
		return themes.light_kanso_pearl(allocator)
	case .Dark:
		return themes.dark_kanso_mist(allocator)
	}
	return {}, false
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
