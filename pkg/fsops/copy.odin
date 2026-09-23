package fsops

import "core:io"
import "core:os"
import "core:path/filepath"

Progress_Proc :: #type proc(percent: int, user_data: rawptr) -> bool

Copy_Progress :: struct {
	total:        i64,
	copied:       i64,
	last_percent: int,
	on_progress:  Progress_Proc,
	user_data:    rawptr,
}

Copy_Entry :: proc(
	source_path, destination_path: string,
	replace: bool = false,
	on_progress: Progress_Proc = nil,
	user_data: rawptr = nil,
) -> os.Error {
	total, size_err := entry_size(source_path)
	if size_err != nil {
		return size_err
	}
	progress := Copy_Progress {
		total        = total,
		last_percent = -1,
		on_progress  = on_progress,
		user_data    = user_data,
	}
	if !copy_report_progress(&progress, false) {
		return os.Error(io.Error.No_Progress)
	}

	actual_destination := destination_path
	staging_path: string
	defer if len(staging_path) > 0 {
		delete(staging_path)
		delete(actual_destination)
	}
	if replace {
		if destination_info, destination_err := os.lstat(destination_path, context.allocator);
		   destination_err == nil {
			os.file_info_delete(destination_info, context.allocator)
			destination_parent := filepath.dir(destination_path)
			staging_path, destination_err = os.make_directory_temp(
				destination_parent,
				".twin-commander-copy-*",
				context.allocator,
			)
			if destination_err != nil {
				return destination_err
			}
			actual_destination =
				filepath.join({staging_path, filepath.base(destination_path)}) or_else ""
		} else if destination_err != .Not_Exist {
			return destination_err
		}
	}

	copy_err := copy_entry_recursive(source_path, actual_destination, &progress)
	if copy_err != nil {
		delete_path(actual_destination)
		if len(staging_path) > 0 {
			os.remove(staging_path)
		}
		return copy_err
	}
	if !copy_report_progress(&progress, true) {
		delete_path(actual_destination)
		if len(staging_path) > 0 {
			os.remove(staging_path)
		}
		return os.Error(io.Error.No_Progress)
	}

	if len(staging_path) > 0 {
		if replace_err := Move_Entry(actual_destination, destination_path, true);
		   replace_err != nil {
			delete_path(actual_destination)
			os.remove(staging_path)
			return replace_err
		}
		return os.remove(staging_path)
	}
	return nil
}

entry_size :: proc(path: string) -> (i64, os.Error) {
	info, stat_err := os.lstat(path, context.allocator)
	if stat_err != nil {
		return 0, stat_err
	}
	defer os.file_info_delete(info, context.allocator)
	if info.type == .Regular {
		return info.size, nil
	}
	if info.type == .Symlink {
		return 0, nil
	}
	if info.type != .Directory {
		return 0, os.Error(io.Error.Unsupported)
	}

	entries, read_err := os.read_all_directory_by_path(path, context.allocator)
	if read_err != nil {
		return 0, read_err
	}
	defer os.file_info_slice_delete(entries, context.allocator)
	total: i64
	for entry in entries {
		size, size_err := entry_size(entry.fullpath)
		if size_err != nil {
			return 0, size_err
		}
		total += size
	}
	return total, nil
}

copy_entry_recursive :: proc(
	source_path, destination_path: string,
	progress: ^Copy_Progress,
) -> os.Error {
	info, stat_err := os.lstat(source_path, context.allocator)
	if stat_err != nil {
		return stat_err
	}
	defer os.file_info_delete(info, context.allocator)
	if info.type == .Regular {
		return copy_file_with_progress(source_path, destination_path, info.mode, progress)
	}
	if info.type == .Symlink {
		target, link_err := os.read_link(source_path, context.allocator)
		if link_err != nil do return link_err
		defer delete(target)
		return os.symlink(target, destination_path)
	}
	if info.type != .Directory {
		return os.Error(io.Error.Unsupported)
	}

	if make_err := os.make_directory(destination_path); make_err != nil {
		return make_err
	}
	entries, read_err := os.read_all_directory_by_path(source_path, context.allocator)
	if read_err != nil {
		return read_err
	}
	defer os.file_info_slice_delete(entries, context.allocator)
	for entry in entries {
		destination_child := filepath.join({destination_path, entry.name}) or_else ""
		if len(destination_child) == 0 {
			return .Invalid_Path
		}
		child_err := copy_entry_recursive(entry.fullpath, destination_child, progress)
		delete(destination_child)
		if child_err != nil {
			return child_err
		}
	}
	return os.change_mode(destination_path, info.mode)
}

copy_file_with_progress :: proc(
	source_path, destination_path: string,
	permissions: os.Permissions,
	progress: ^Copy_Progress,
) -> os.Error {
	source, source_err := os.open(source_path)
	if source_err != nil {
		return source_err
	}
	defer os.close(source)
	destination, destination_err := os.open(
		destination_path,
		{.Write, .Create, .Trunc},
		permissions,
	)
	if destination_err != nil {
		return destination_err
	}
	defer os.close(destination)

	buffer: [64 * 1024]byte
	for {
		read_count, read_err := os.read(source, buffer[:])
		if read_count > 0 {
			written := 0
			for written < read_count {
				write_count, write_err := os.write(destination, buffer[written:read_count])
				if write_err != nil {
					return write_err
				}
				if write_count == 0 {
					return os.Error(io.Error.No_Progress)
				}
				written += write_count
			}
			progress.copied += i64(read_count)
			if !copy_report_progress(progress, false) {
				return os.Error(io.Error.No_Progress)
			}
		}
		if read_err != nil {
			if read_err == os.Error(io.Error.EOF) {
				break
			}
			return read_err
		}
		if read_count == 0 {
			break
		}
	}
	return nil
}

copy_report_progress :: proc(progress: ^Copy_Progress, complete: bool) -> bool {
	percent :=
		100 if complete || progress.total == 0 else int(min(progress.copied * 100 / progress.total, 100))
	return report_progress(
		progress.on_progress,
		progress.user_data,
		percent,
		&progress.last_percent,
	)
}

Copy_File :: proc(
	source_path, destination_path: string,
	total_size: i64,
	permissions: os.Permissions,
	on_progress: Progress_Proc = nil,
	user_data: rawptr = nil,
) -> os.Error {
	source, source_err := os.open(source_path)
	if source_err != nil {
		return source_err
	}
	defer os.close(source)

	destination, destination_err := os.open(
		destination_path,
		{.Write, .Create, .Trunc},
		permissions,
	)
	if destination_err != nil {
		return destination_err
	}
	defer os.close(destination)

	last_percent := -1
	if !report_progress(on_progress, user_data, 0, &last_percent) {
		return os.Error(io.Error.No_Progress)
	}

	buffer: [64 * 1024]byte
	copied: i64
	for {
		read_count, read_err := os.read(source, buffer[:])
		if read_count > 0 {
			written := 0
			for written < read_count {
				write_count, write_err := os.write(destination, buffer[written:read_count])
				if write_err != nil {
					return write_err
				}
				if write_count == 0 {
					return os.Error(io.Error.No_Progress)
				}
				written += write_count
			}

			copied += i64(read_count)
			percent := 100
			if total_size > 0 {
				percent = int(min(copied * 100 / total_size, 100))
			}
			if !report_progress(on_progress, user_data, percent, &last_percent) {
				return os.Error(io.Error.No_Progress)
			}
		}

		if read_err != nil {
			if read_err == os.Error(io.Error.EOF) {
				break
			}
			return read_err
		}
		if read_count == 0 {
			break
		}
	}

	if !report_progress(on_progress, user_data, 100, &last_percent) {
		return os.Error(io.Error.No_Progress)
	}
	return nil
}

report_progress :: proc(
	on_progress: Progress_Proc,
	user_data: rawptr,
	percent: int,
	last_percent: ^int,
) -> bool {
	if percent == last_percent^ {
		return true
	}
	last_percent^ = percent
	return on_progress == nil || on_progress(percent, user_data)
}
