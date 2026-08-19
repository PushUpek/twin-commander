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
copy_entry_copies_nested_and_empty_directories_with_progress :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp(
		"",
		"twin-commander-copy-dir-*",
		context.allocator,
	)
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

	source_dir := filepath.join({temp_path, "source"}) or_else ""
	defer delete(source_dir)
	empty_dir := filepath.join({source_dir, "empty"}) or_else ""
	defer delete(empty_dir)
	nested_dir := filepath.join({source_dir, "nested"}) or_else ""
	defer delete(nested_dir)
	nested_file := filepath.join({nested_dir, "report.txt"}) or_else ""
	defer delete(nested_file)
	destination_dir := filepath.join({temp_path, "destination"}) or_else ""
	defer delete(destination_dir)
	destination_empty := filepath.join({destination_dir, "empty"}) or_else ""
	defer delete(destination_empty)
	destination_file := filepath.join({destination_dir, "nested", "report.txt"}) or_else ""
	defer delete(destination_file)

	testing.expect(t, os.make_directory(source_dir) == nil)
	testing.expect(t, os.make_directory(empty_dir) == nil)
	testing.expect(t, os.make_directory(nested_dir) == nil)
	testing.expect(t, os.write_entire_file_from_string(nested_file, "directory copy") == nil)

	progress: Progress_Log
	copy_err := Copy_Entry(source_dir, destination_dir, false, record_progress, rawptr(&progress))
	testing.expectf(t, copy_err == nil, "directory copy failed: %s", os.error_string(copy_err))
	expect_info, empty_err := os.stat(destination_empty, context.allocator)
	defer if empty_err == nil {
		os.file_info_delete(expect_info, context.allocator)
	}
	testing.expect(t, empty_err == nil)
	testing.expect_value(t, expect_info.type, os.File_Type.Directory)
	copied, read_err := os.read_entire_file(destination_file, context.allocator)
	defer delete(copied)
	testing.expect(t, read_err == nil)
	testing.expect_value(t, string(copied), "directory copy")
	testing.expect(t, progress.count >= 2)
	testing.expect_value(t, progress.values[0], 0)
	testing.expect_value(t, progress.values[progress.count - 1], 100)
}

@(test)
copy_entry_replaces_existing_directory :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp(
		"",
		"twin-commander-copy-replace-*",
		context.allocator,
	)
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

	source_dir := filepath.join({temp_path, "source"}) or_else ""
	defer delete(source_dir)
	destination_dir := filepath.join({temp_path, "destination"}) or_else ""
	defer delete(destination_dir)
	new_file := filepath.join({source_dir, "new.txt"}) or_else ""
	defer delete(new_file)
	old_file := filepath.join({destination_dir, "old.txt"}) or_else ""
	defer delete(old_file)
	copied_file := filepath.join({destination_dir, "new.txt"}) or_else ""
	defer delete(copied_file)
	testing.expect(t, os.make_directory(source_dir) == nil)
	testing.expect(t, os.make_directory(destination_dir) == nil)
	testing.expect(t, os.write_entire_file_from_string(new_file, "new") == nil)
	testing.expect(t, os.write_entire_file_from_string(old_file, "old") == nil)

	copy_err := Copy_Entry(source_dir, destination_dir, true)
	testing.expectf(t, copy_err == nil, "replace copy failed: %s", os.error_string(copy_err))
	_, old_err := os.stat(old_file, context.allocator)
	testing.expect_value(t, old_err, os.Error(.Not_Exist))
	copied, read_err := os.read_entire_file(copied_file, context.allocator)
	defer delete(copied)
	testing.expect(t, read_err == nil)
	testing.expect_value(t, string(copied), "new")
}

@(test)
move_entry_moves_files_and_directories :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp("", "twin-commander-move-*", context.allocator)
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

	source_file := filepath.join({temp_path, "source.txt"}) or_else ""
	defer delete(source_file)
	destination_file := filepath.join({temp_path, "destination.txt"}) or_else ""
	defer delete(destination_file)
	testing.expect(t, os.write_entire_file_from_string(source_file, "moved") == nil)
	testing.expect(t, Move_Entry(source_file, destination_file) == nil)
	_, source_err := os.stat(source_file, context.allocator)
	testing.expect_value(t, source_err, os.Error(.Not_Exist))
	moved_content, read_err := os.read_entire_file(destination_file, context.allocator)
	defer delete(moved_content)
	testing.expect(t, read_err == nil)
	testing.expect_value(t, string(moved_content), "moved")

	source_dir := filepath.join({temp_path, "source-dir"}) or_else ""
	defer delete(source_dir)
	destination_dir := filepath.join({temp_path, "destination-dir"}) or_else ""
	defer delete(destination_dir)
	nested_file := filepath.join({source_dir, "nested.txt"}) or_else ""
	defer delete(nested_file)
	moved_nested_file := filepath.join({destination_dir, "nested.txt"}) or_else ""
	defer delete(moved_nested_file)
	testing.expect(t, os.make_directory(source_dir) == nil)
	testing.expect(t, os.write_entire_file_from_string(nested_file, "nested") == nil)
	testing.expect(t, Move_Entry(source_dir, destination_dir) == nil)
	nested_content, nested_err := os.read_entire_file(moved_nested_file, context.allocator)
	defer delete(nested_content)
	testing.expect(t, nested_err == nil)
	testing.expect_value(t, string(nested_content), "nested")
}

@(test)
move_entry_replaces_existing_destination_and_delete_entry_is_recursive :: proc(t: ^testing.T) {
	temp_path, temp_err := os.make_directory_temp(
		"",
		"twin-commander-replace-*",
		context.allocator,
	)
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

	source_dir := filepath.join({temp_path, "source"}) or_else ""
	defer delete(source_dir)
	destination_dir := filepath.join({temp_path, "destination"}) or_else ""
	defer delete(destination_dir)
	source_file := filepath.join({source_dir, "new.txt"}) or_else ""
	defer delete(source_file)
	old_file := filepath.join({destination_dir, "old.txt"}) or_else ""
	defer delete(old_file)
	testing.expect(t, os.make_directory(source_dir) == nil)
	testing.expect(t, os.make_directory(destination_dir) == nil)
	testing.expect(t, os.write_entire_file_from_string(source_file, "new") == nil)
	testing.expect(t, os.write_entire_file_from_string(old_file, "old") == nil)
	testing.expect(t, Move_Entry(source_dir, destination_dir, true) == nil)
	_, old_err := os.stat(old_file, context.allocator)
	testing.expect_value(t, old_err, os.Error(.Not_Exist))
	testing.expect(t, Delete_Entry(destination_dir) == nil)
	_, deleted_err := os.stat(destination_dir, context.allocator)
	testing.expect_value(t, deleted_err, os.Error(.Not_Exist))
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
