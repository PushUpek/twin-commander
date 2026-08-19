package fsops

import "core:os"
import "core:path/filepath"

Move_Entry :: proc(source_path, destination_path: string, replace: bool = false) -> os.Error {
	if !replace {
		return os.rename(source_path, destination_path)
	}

	destination_info, destination_err := os.stat(destination_path, context.allocator)
	if destination_err == .Not_Exist {
		return os.rename(source_path, destination_path)
	}
	if destination_err != nil {
		return destination_err
	}
	os.file_info_delete(destination_info, context.allocator)

	// Najpierw odsuwamy istniejący cel do katalogu tymczasowego. Dzięki temu
	// błąd rename (np. między systemami plików) nie niszczy zastępowanego elementu.
	destination_parent := filepath.dir(destination_path)
	staging_path, staging_err := os.make_directory_temp(
		destination_parent,
		".twin-commander-move-*",
		context.allocator,
	)
	if staging_err != nil {
		return staging_err
	}
	defer delete(staging_path)
	backup_path := filepath.join({staging_path, filepath.base(destination_path)}) or_else ""
	defer delete(backup_path)
	if len(backup_path) == 0 {
		os.remove(staging_path)
		return .Invalid_Path
	}
	if backup_err := os.rename(destination_path, backup_path); backup_err != nil {
		os.remove(staging_path)
		return backup_err
	}

	if move_err := os.rename(source_path, destination_path); move_err != nil {
		rollback_err := os.rename(backup_path, destination_path)
		os.remove(staging_path)
		if rollback_err != nil {
			return rollback_err
		}
		return move_err
	}

	if delete_err := delete_path(backup_path); delete_err != nil {
		return delete_err
	}
	return os.remove(staging_path)
}

Delete_Entry :: proc(path: string) -> os.Error {
	return delete_path(path)
}

delete_path :: proc(path: string) -> os.Error {
	info, stat_err := os.stat(path, context.allocator)
	if stat_err != nil {
		return stat_err
	}
	is_directory := info.type == .Directory
	os.file_info_delete(info, context.allocator)
	if is_directory {
		return os.remove_all(path)
	}
	return os.remove(path)
}
