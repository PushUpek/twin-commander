package fsops

import "base:runtime"
import "core:os"
import "core:path/filepath"
import "core:strings"

Load_Directory :: proc(
	path: string,
	allocator: runtime.Allocator,
) -> (
	absolute_path: string,
	files: []os.File_Info,
	err: os.Error,
) {
	absolute_path, err = filepath.abs(path, allocator)
	if err != nil {
		return
	}

	files, err = os.read_all_directory_by_path(absolute_path, allocator)
	if err != nil {
		delete(absolute_path, allocator)
		absolute_path = ""
		return
	}

	sort_files(files)
	return
}

sort_files :: proc(files: []os.File_Info) {
	for index in 1 ..< len(files) {
		item := files[index]
		position := index
		for position > 0 && file_before(item, files[position - 1]) {
			files[position] = files[position - 1]
			position -= 1
		}
		files[position] = item
	}
}

file_before :: proc(left, right: os.File_Info) -> bool {
	left_dir := left.type == .Directory
	right_dir := right.type == .Directory
	if left_dir != right_dir {
		return left_dir
	}
	return strings.compare(left.name, right.name) < 0
}
