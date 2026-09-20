package fsops

import "core:os"
import "core:path/filepath"
import "core:sys/posix"

Move_Entry :: proc(
	source_path, destination_path: string,
	replace: bool = false,
	on_progress: Progress_Proc = nil,
	user_data: rawptr = nil,
) -> os.Error {
	if !replace {
		move_err := os.rename(source_path, destination_path)
		if is_cross_device(move_err) {
			return copy_then_delete(source_path, destination_path, false, on_progress, user_data)
		}
		return move_err
	}

	destination_info, destination_err := os.lstat(destination_path, context.allocator)
	if destination_err == .Not_Exist {
		move_err := os.rename(source_path, destination_path)
		if is_cross_device(move_err) {
			return copy_then_delete(source_path, destination_path, false, on_progress, user_data)
		}
		return move_err
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
		if is_cross_device(move_err) {
			return copy_then_delete(source_path, destination_path, true, on_progress, user_data)
		}
		return move_err
	}

	if delete_err := delete_path(backup_path); delete_err != nil {
		return delete_err
	}
	return os.remove(staging_path)
}

is_cross_device :: proc(err: os.Error) -> bool {
	platform_error, ok := os.is_platform_error(err)
	return ok && platform_error == i32(posix.Errno.EXDEV)
}

copy_then_delete :: proc(
	source_path, destination_path: string,
	replace: bool,
	on_progress: Progress_Proc = nil,
	user_data: rawptr = nil,
) -> os.Error {
	if copy_err := Copy_Entry(source_path, destination_path, replace, on_progress, user_data); copy_err != nil {
		return copy_err
	}
	if delete_err := delete_path(source_path); delete_err != nil {
		// The source remains authoritative if cleanup fails; do not destroy the completed copy.
		return delete_err
	}
	return nil
}

Delete_Entry :: proc(path: string) -> os.Error {
	return delete_path(path)
}

delete_path :: proc(path: string) -> os.Error {
	info, stat_err := os.lstat(path, context.allocator)
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
