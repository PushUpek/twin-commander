package fsops

import "base:runtime"
import "core:os"
import "core:path/filepath"
import "core:sort"
import "core:strings"
import "core:time"

Sort_Kind :: enum {
	Name,
	Extension,
	Size,
	Modified,
}

Directory_Options :: struct {
	show_hidden: bool,
	filter:      string,
	sort_kind:   Sort_Kind,
	reverse:     bool,
}

Load_Directory :: proc(
	path: string,
	allocator: runtime.Allocator,
	options: Directory_Options = {},
) -> (
	absolute_path: string,
	files: []os.File_Info,
	err: os.Error,
) {
	absolute_path, err = filepath.abs(path, allocator)
	if err != nil {
		return
	}

	raw_files, read_err := os.read_all_directory_by_path(absolute_path, allocator)
	if read_err != nil {
		delete(absolute_path, allocator)
		absolute_path = ""
		err = read_err
		return
	}
	defer os.file_info_slice_delete(raw_files, allocator)

	selected := make([dynamic]os.File_Info, 0, len(raw_files), allocator)
	defer delete(selected)
	for file in raw_files {
		if !options.show_hidden && strings.has_prefix(file.name, ".") {
			continue
		}
		if len(options.filter) > 0 && !strings.contains(strings.to_lower(file.name, context.temp_allocator), strings.to_lower(options.filter, context.temp_allocator)) {
			continue
		}
		cloned, clone_err := os.file_info_clone(file, allocator)
		if clone_err != nil {
			for selected_file in selected do os.file_info_delete(selected_file, allocator)
			delete(absolute_path, allocator)
			absolute_path = ""
			err = clone_err
			return
		}
		append(&selected, cloned)
	}
	files = make([]os.File_Info, len(selected), allocator)
	copy(files, selected[:])
	if err != nil {
		delete(absolute_path, allocator)
		absolute_path = ""
		return
	}

	sort_files(files, options.sort_kind, options.reverse)
	return
}

File_Sort_Context :: struct {
	files:   []os.File_Info,
	kind:    Sort_Kind,
	reverse: bool,
}

sort_files :: proc(files: []os.File_Info, kind: Sort_Kind = .Name, reverse := false) {
	if len(files) < 2 do return
	state := File_Sort_Context{files = files, kind = kind, reverse = reverse}
	sort.sort(sort.Interface{
		collection = rawptr(&state),
		len = proc(it: sort.Interface) -> int {
			return len((^File_Sort_Context)(it.collection).files)
		},
		less = proc(it: sort.Interface, i, j: int) -> bool {
			state := (^File_Sort_Context)(it.collection)
			return file_before(state.files[i], state.files[j], state.kind, state.reverse)
		},
		swap = proc(it: sort.Interface, i, j: int) {
			files := (^File_Sort_Context)(it.collection).files
			files[i], files[j] = files[j], files[i]
		},
	})
}

file_before :: proc(left, right: os.File_Info, kind: Sort_Kind = .Name, reverse := false) -> bool {
	left_dir := left.type == .Directory
	right_dir := right.type == .Directory
	if left_dir != right_dir {
		return left_dir
	}
	comparison: int
	switch kind {
	case .Extension:
		comparison = strings.compare(filepath.ext(left.name), filepath.ext(right.name))
	case .Size:
		comparison = -1 if left.size < right.size else 1 if left.size > right.size else 0
	case .Modified:
		left_time := time.time_to_unix_nano(left.modification_time)
		right_time := time.time_to_unix_nano(right.modification_time)
		comparison = -1 if left_time < right_time else 1 if left_time > right_time else 0
	case .Name:
	}
	if comparison == 0 {
		comparison = strings.compare(left.name, right.name)
	}
	if reverse do comparison = -comparison
	return comparison < 0
}
