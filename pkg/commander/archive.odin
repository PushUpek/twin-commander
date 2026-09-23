package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

archive_kind :: proc(path: string) -> (zip: bool, ok: bool) {
	lower := strings.to_lower(path, context.temp_allocator) or_else path
	if strings.has_suffix(lower, ".zip") do return true, true
	for suffix in ([]string{".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tbz2", ".tar.xz", ".txz"}) {
		if strings.has_suffix(lower, suffix) do return false, true
	}
	return false, false
}

open_archive :: proc(app: ^App_State, path: string) -> bool {
	is_zip, supported := archive_kind(path)
	if !supported do return false
	source := strings.clone(path) or_else ""
	defer delete(source)
	panel := &app.panels[app.active_panel]
	if len(panel.archive_root) > 0 {
		set_status(app, strings.clone(tr("Zagnieżdżone archiwa nie są jeszcze obsługiwane")) or_else "")
		return true
	}
	temp_root, err := os.make_directory_temp("", "twin-commander-archive-*", context.allocator)
	if err != nil {
		set_status(app, fmt.aprintf(tr("Nie można przygotować archiwum: %s"), os.error_string(err)))
		return true
	}
	content := filepath.join({temp_root, "content"}) or_else ""
	listing := filepath.join({temp_root, "listing"}) or_else ""
	defer delete(temp_root)
	defer delete(content)
	defer delete(listing)
	if os.make_directory(content) != nil {
		os.remove_all(temp_root)
		return true
	}
	if !archive_listing_safe(source, listing, is_zip) {
		os.remove_all(temp_root)
		set_status(app, strings.clone(tr("Archiwum zawiera niebezpieczną ścieżkę lub jest uszkodzone")) or_else "")
		return true
	}
	command := []string{"tar", "-xf", source, "-C", content}
	if is_zip do command = []string{"unzip", "-qq", source, "-d", content}
	if !run_archive_process(command, nil) {
		os.remove_all(temp_root)
		set_status(app, strings.clone(tr("Nie można rozpakować archiwum")) or_else "")
		return true
	}
	parent := strings.clone(panel.path) or_else ""
	if load_err := panel_load(panel, content, false); load_err != nil {
		delete(parent)
		os.remove_all(temp_root)
		set_status(app, fmt.aprintf(tr("Nie można otworzyć archiwum: %s"), os.error_string(load_err)))
		return true
	}
	panel.archive_root = strings.clone(panel.path) or_else ""
	panel.archive_source = strings.clone(source) or_else ""
	panel.archive_parent = parent
	set_status(app, fmt.aprintf(tr("Archiwum: %s"), filepath.base(source)))
	return true
}

panel_is_archive :: proc(panel: ^Panel_State) -> bool {
	return panel != nil && len(panel.archive_root) > 0
}

archive_read_only_status :: proc(app: ^App_State) {
	set_status(app, strings.clone(tr("Widok archiwum jest tylko do odczytu")) or_else "")
}

archive_listing_safe :: proc(path, listing: string, is_zip: bool) -> bool {
	file, err := os.create(listing)
	if err != nil do return false
	command := []string{"tar", "-tf", path}
	if is_zip do command = []string{"unzip", "-Z1", path}
	ok := run_archive_process(command, file)
	os.close(file)
	if !ok do return false
	data, read_err := os.read_entire_file(listing, context.temp_allocator)
	if read_err != nil do return false
	text := string(data)
	for raw in strings.split_lines_iterator(&text) {
		entry := strings.trim(raw, " \t\r")
		if len(entry) == 0 do continue
		if filepath.is_abs(entry) do return false
		remaining := entry
		for component in strings.split_iterator(&remaining, "/") {
			if component == ".." do return false
		}
	}
	return true
}

run_archive_process :: proc(command: []string, stdout: ^os.File) -> bool {
	output := stdout
	if output == nil do output = os.stdout
	dev_null, null_err := os.open("/dev/null", {.Write})
	if null_err != nil do return false
	defer os.close(dev_null)
	process, err := os.process_start(os.Process_Desc{command = command, stdout = output, stderr = dev_null})
	if err != nil do return false
	state, wait_err := os.process_wait(process)
	return wait_err == nil && state.success && state.exit_code == 0
}

leave_archive :: proc(panel: ^Panel_State) -> bool {
	if len(panel.archive_root) == 0 || panel.path != panel.archive_root do return false
	return close_archive(panel)
}

close_archive :: proc(panel: ^Panel_State) -> bool {
	if len(panel.archive_root) == 0 do return false
	root_parent := filepath.dir(panel.archive_root)
	parent := strings.clone(panel.archive_parent) or_else ""
	archive_name := filepath.base(panel.archive_source)
	err := panel_load(panel, parent, false)
	delete(parent)
	if err != nil do return false
	panel_select_name(panel, archive_name)
	os.remove_all(root_parent)
	delete(panel.archive_root)
	delete(panel.archive_source)
	delete(panel.archive_parent)
	panel.archive_root = ""
	panel.archive_source = ""
	panel.archive_parent = ""
	return true
}
