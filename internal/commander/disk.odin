package commander

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"

update_panel_space :: proc(panel: ^Panel_State) {
	panel.space_known = false
	path := strings.clone_to_cstring(panel.path, context.temp_allocator) or_else nil
	if path == nil do return
	stats: posix.statvfs_t
	if posix.statvfs(path, &stats) != nil do return
	block_size := u64(stats.f_frsize)
	free := u128(u64(stats.f_bavail)) * u128(block_size)
	total := u128(u64(stats.f_blocks)) * u128(block_size)
	panel.free_bytes = i64(min(free, u128(max(i64))))
	panel.total_bytes = i64(min(total, u128(max(i64))))
	panel.space_known = true
}

calculate_selected_size :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	if panel.selected <= 0 || panel.selected > len(panel.files) {
		set_status(app, strings.clone(tr("Wybierz plik lub katalog")) or_else "")
		return
	}
	file := &panel.files[panel.selected - 1]
	size := file.size
	if file.type == .Directory {
		size = directory_size(file.fullpath)
		file.size = size
	}
	buffer: [32]byte
	set_status(app, fmt.aprintf(tr("Rozmiar %s: %s (%d bajtów)"), file.name, format_file_size(buffer[:], size), size))
}

directory_size :: proc(path: string) -> i64 {
	total: i64
	walker := os.walker_create(path)
	defer os.walker_destroy(&walker)
	for info in os.walker_walk(&walker) {
		if info.type == .Regular || info.type == .Symlink {
			if info.size > 0 && total <= max(i64) - info.size do total += info.size
		}
	}
	return total
}
