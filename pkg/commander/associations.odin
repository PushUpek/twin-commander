package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:pkg/tui"

associations_load :: proc(app: ^App_State) {
	command := "xdg-open"
	when ODIN_OS == .Darwin do command = "open"
	for extension in ([]string{".pdf", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".mp3", ".mp4"}) {
		association_set(app, extension, command)
	}
	path := os.get_env("TWIN_COMMANDER_ASSOCIATIONS_FILE", context.temp_allocator)
	if len(path) == 0 {
		config_dir, err := os.user_config_dir(context.temp_allocator)
		if err == nil do path = filepath.join({config_dir, "twin-commander", "associations"}, context.temp_allocator) or_else ""
	}
	if len(path) == 0 do return
	data, err := os.read_entire_file(path, context.temp_allocator)
	if err != nil do return
	text := string(data)
	for raw_line in strings.split_lines_iterator(&text) {
		line := strings.trim(raw_line, " \t\r")
		if len(line) == 0 || line[0] == '#' do continue
		equals := strings.index_byte(line, '=')
		if equals < 1 do continue
		extension := strings.trim(line[:equals], " \t")
		value := strings.trim(line[equals + 1:], " \t")
		if len(value) < 2 || value[0] != '"' || value[len(value) - 1] != '"' do continue
		association_set(app, extension, value[1:len(value) - 1])
	}
}

association_set :: proc(app: ^App_State, extension, command: string) {
	if len(extension) == 0 || len(command) == 0 do return
	normalized := strings.to_lower(extension, context.temp_allocator) or_else extension
	for &association in app.associations {
		if association.extension == normalized {
			delete(association.command)
			association.command = strings.clone(command) or_else ""
			return
		}
	}
	append(&app.associations, File_Association{
		extension = strings.clone(normalized) or_else "",
		command = strings.clone(command) or_else "",
	})
}

association_for :: proc(app: ^App_State, path: string) -> string {
	extension := strings.to_lower(filepath.ext(path), context.temp_allocator) or_else filepath.ext(path)
	for association in app.associations {
		if association.extension == extension do return association.command
	}
	return ""
}

open_associated_file :: proc(ctx: ^tui.Context, app: ^App_State, path: string, running: ^bool) -> bool {
	command_name := association_for(app, path)
	if len(command_name) == 0 do return false
	panel := &app.panels[app.active_panel]
	command := []string{"/bin/sh", "-c", "exec $1 \"$2\"", "twin-commander", command_name, path}
	tui.suspend(ctx)
	process, start_err := os.process_start(os.Process_Desc{
		command = command,
		working_dir = panel.path,
		stdin = os.stdin,
		stdout = os.stdout,
		stderr = os.stderr,
	})
	state: os.Process_State
	wait_err: os.Error
	if start_err == nil do state, wait_err = os.process_wait(process)
	if !tui.resume(ctx) {
		if running != nil do running^ = false
		return true
	}
	if start_err != nil {
		set_status(app, fmt.aprintf(tr("Nie można uruchomić skojarzonego programu: %s"), os.error_string(start_err)))
	} else if wait_err != nil || !state.success {
		set_status(app, fmt.aprintf(tr("Skojarzony program zakończył się kodem %d"), state.exit_code))
	} else {
		set_status(app, fmt.aprintf(tr("Otwarto przez: %s"), command_name))
	}
	return true
}
