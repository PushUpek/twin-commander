package commander

import "core:os"
import "core:path/filepath"
import "core:testing"
import "tc:pkg/tui"

@(test)
user_config_directory_takes_precedence_over_legacy_location :: proc(t: ^testing.T) {
	when ODIN_OS != .Windows {
		root, err := os.make_directory_temp("", "twin-commander-config-*", context.allocator)
		if !testing.expect(t, err == nil) do return
		defer delete(root)
		defer os.remove_all(root)
		legacy_base := filepath.join({root, "legacy"}) or_else ""
		preferred := filepath.join({root, ".config", "twin-commander"}) or_else ""
		defer delete(legacy_base)
		defer delete(preferred)
		testing.expect_value(t, config_root_from_dirs(root, legacy_base, context.temp_allocator), filepath.join({legacy_base, "twin-commander"}, context.temp_allocator) or_else "")
		testing.expect(t, os.make_directory_all(preferred) == nil)
		testing.expect_value(t, config_root_from_dirs(root, legacy_base, context.temp_allocator), preferred)
	}
}

@(test)
user_theme_overrides_bundled_theme_and_missing_file_falls_back :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-theme-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	filename := "dark_kanso_mist.toml"
	path := filepath.join({root, filename}) or_else ""
	defer delete(path)

	fallback, fallback_ok := load_default_theme_from_user_dir(filename, root, context.allocator)
	defer destroy_theme(&fallback)
	testing.expect(t, fallback_ok)
	testing.expect_value(t, fallback.name, "Kanso Mist")

	testing.expect(t, os.write_entire_file_from_string(path, "name = \"Personal\"\n[screen]\nbackground = \"#010203\"\n") == nil)
	custom, custom_ok := load_default_theme_from_user_dir(filename, root, context.allocator)
	defer destroy_theme(&custom)
	testing.expect(t, custom_ok)
	testing.expect_value(t, custom.name, "Personal")
	testing.expect_value(t, custom.screen.background_rgb, tui.rgb(0x010203))
	testing.expect_value(t, custom.screen.foreground_rgb, fallback.screen.foreground_rgb)
}
