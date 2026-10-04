package commander

import "base:runtime"
import "core:os"
import "core:path/filepath"

config_directory_exists :: proc(path: string) -> bool {
	if len(path) == 0 do return false
	info, err := os.stat(path, context.temp_allocator)
	if err != nil do return false
	defer os.file_info_delete(info, context.temp_allocator)
	return info.type == .Directory
}

preferred_config_root :: proc(home, legacy_base: string, allocator: runtime.Allocator) -> string {
	when ODIN_OS == .Windows {
		if len(legacy_base) == 0 do return ""
		return filepath.join({legacy_base, "twin-commander"}, allocator) or_else ""
	} else {
		if len(home) == 0 do return ""
		return filepath.join({home, ".config", "twin-commander"}, allocator) or_else ""
	}
}

config_root_from_dirs :: proc(home, legacy_base: string, allocator: runtime.Allocator) -> string {
	preferred := preferred_config_root(home, legacy_base, context.temp_allocator)
	if config_directory_exists(preferred) {
		return filepath.join({preferred}, allocator) or_else ""
	}
	if len(legacy_base) == 0 do return ""
	return filepath.join({legacy_base, "twin-commander"}, allocator) or_else ""
}

user_config_root :: proc() -> string {
	home, _ := os.user_home_dir(context.temp_allocator)
	legacy_base, _ := os.user_config_dir(context.temp_allocator)
	return config_root_from_dirs(home, legacy_base, context.temp_allocator)
}

user_config_file :: proc(filename: string) -> string {
	root := user_config_root()
	if len(root) == 0 do return ""
	return filepath.join({root, filename}, context.temp_allocator) or_else ""
}

user_themes_directory :: proc() -> string {
	home, _ := os.user_home_dir(context.temp_allocator)
	legacy_base, _ := os.user_config_dir(context.temp_allocator)
	root := preferred_config_root(home, legacy_base, context.temp_allocator)
	if len(root) == 0 do return ""
	themes_dir := filepath.join({root, "themes"}, context.temp_allocator) or_else ""
	if !config_directory_exists(themes_dir) do return ""
	return themes_dir
}
