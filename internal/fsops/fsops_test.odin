package fsops

import "core:os"
import "core:path/filepath"
import "core:testing"

Progress_Log :: struct {
	values: [128]int,
	count:  int,
}

@(test)
copy_file_reports_progress :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp("", "twin-commander-copy-*", context.allocator)
	if !testing.expectf(
		t,
		temp_err == nil,
		"cannot create temp directory: %s",
		os.error_string(temp_err),
	) {
		return
	}
	defer delete(temp_path)
	defer os.remove_all(temp_path)

	source_path := filepath.join({temp_path, "source.txt"}) or_else ""
	defer delete(source_path)
	destination_path := filepath.join({temp_path, "destination.txt"}) or_else ""
	defer delete(destination_path)

	content := "Twin Commander copy test"
	write_err := os.write_entire_file_from_string(source_path, content)
	if !testing.expectf(
		t,
		write_err == nil,
		"cannot write source: %s",
		os.error_string(write_err),
	) {
		return
	}

	progress: Progress_Log
	copy_err := Copy_File(
		source_path,
		destination_path,
		i64(len(content)),
		os.Permissions_Default_File,
		record_progress,
		rawptr(&progress),
	)
	testing.expectf(t, copy_err == nil, "copy failed: %s", os.error_string(copy_err))

	copied, read_err := os.read_entire_file(destination_path, context.allocator)
	defer delete(copied)
	testing.expectf(t, read_err == nil, "cannot read destination: %s", os.error_string(read_err))
	testing.expect_value(t, string(copied), content)
	testing.expect(t, progress.count >= 2)
	testing.expect_value(t, progress.values[0], 0)
	testing.expect_value(t, progress.values[progress.count - 1], 100)
}

record_progress :: proc(percent: int, user_data: rawptr) -> bool {
	progress := (^Progress_Log)(user_data)
	if progress.count < len(progress.values) {
		progress.values[progress.count] = percent
		progress.count += 1
	}
	return true
}

@(test)
load_directory_sorts_directories_before_files :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp("", "twin-commander-list-*", context.allocator)
	if !testing.expectf(
		t,
		temp_err == nil,
		"cannot create temp directory: %s",
		os.error_string(temp_err),
	) {
		return
	}
	defer delete(temp_path)
	defer os.remove_all(temp_path)

	z_dir := filepath.join({temp_path, "z-dir"}) or_else ""
	defer delete(z_dir)
	a_dir := filepath.join({temp_path, "a-dir"}) or_else ""
	defer delete(a_dir)
	z_file := filepath.join({temp_path, "z.txt"}) or_else ""
	defer delete(z_file)
	a_file := filepath.join({temp_path, "a.txt"}) or_else ""
	defer delete(a_file)

	testing.expect(t, os.make_directory(z_dir) == nil)
	testing.expect(t, os.make_directory(a_dir) == nil)
	testing.expect(t, os.write_entire_file_from_string(z_file, "z") == nil)
	testing.expect(t, os.write_entire_file_from_string(a_file, "a") == nil)

	absolute_path, files, load_err := Load_Directory(temp_path, context.allocator)
	defer delete(absolute_path)
	defer if files != nil {
		os.file_info_slice_delete(files, context.allocator)
	}
	if !testing.expectf(
		t,
		load_err == nil,
		"cannot load directory: %s",
		os.error_string(load_err),
	) {
		return
	}

	testing.expect_value(t, len(files), 4)
	if len(files) == 4 {
		testing.expect_value(t, files[0].name, "a-dir")
		testing.expect_value(t, files[1].name, "z-dir")
		testing.expect_value(t, files[2].name, "a.txt")
		testing.expect_value(t, files[3].name, "z.txt")
	}
}
