package fsops

import "core:io"
import "core:os"

Progress_Proc :: #type proc(percent: int, user_data: rawptr) -> bool

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
