package commander

import "core:fmt"
import "core:os"
import "core:strings"
import "tc:internal/tui"

External_Action :: enum {
	View,
	Edit,
}

open_selected_file :: proc(
	ctx: ^tui.Context,
	app: ^App_State,
	action: External_Action,
	running: ^bool,
) {
	if ctx == nil || app == nil {
		return
	}

	panel := &app.panels[app.active_panel]
	if panel.selected == 0 || panel.selected > len(panel.files) {
		set_status(app, strings.clone("Wybierz plik") or_else "")
		return
	}
	file := panel.files[panel.selected - 1]
	if file.type == .Directory {
		set_status(app, fmt.aprintf("%s jest katalogiem", file.name))
		return
	}

	tool := strings.clone(external_tool(action)) or_else ""
	defer delete(tool)
	if len(tool) == 0 {
		set_status(app, strings.clone("Nie skonfigurowano programu zewnętrznego") or_else "")
		return
	}

	// Rozwinięcie bez cudzysłowu celowo pozwala na standardowe wartości typu
	// EDITOR="code --wait". Ścieżka pliku pozostaje osobnym, cytowanym argumentem.
	script := "exec $1 \"$2\""
	if action == .View {
		script = "LESSSECURE=1; export LESSSECURE; exec $1 \"$2\""
	}
	command := []string{"/bin/sh", "-c", script, "twin-commander", tool, file.fullpath}

	tui.suspend(ctx)
	process, start_err := os.process_start(os.Process_Desc{
		command = command,
		stdin = os.stdin,
		stdout = os.stdout,
		stderr = os.stderr,
	})
	state: os.Process_State
	wait_err: os.Error
	if start_err == nil {
		state, wait_err = os.process_wait(process)
	}
	if !tui.resume(ctx) {
		if running != nil {
			running^ = false
		}
		return
	}

	if start_err != nil {
		set_status(app, fmt.aprintf("Nie można uruchomić %s: %s", tool, os.error_string(start_err)))
		return
	}
	if wait_err != nil {
		set_status(app, fmt.aprintf("Błąd programu %s: %s", tool, os.error_string(wait_err)))
		return
	}
	if !state.success || state.exit_code != 0 {
		set_status(app, fmt.aprintf("Program %s zakończył się kodem %d", tool, state.exit_code))
		return
	}

	if action == .Edit {
		selected_name := strings.clone(file.name) or_else ""
		defer delete(selected_name)
		if err := panel_refresh(panel); err != nil {
			set_status(app, fmt.aprintf("Nie można odświeżyć katalogu: %s", os.error_string(err)))
			return
		}
		panel_select_name(panel, selected_name)
		set_status(app, fmt.aprintf("Zamknięto edycję %s", selected_name))
	} else {
		set_status(app, fmt.aprintf("Zamknięto podgląd %s", file.name))
	}
}

external_tool :: proc(action: External_Action) -> string {
	if action == .View {
		if pager := os.get_env("PAGER", context.temp_allocator); len(pager) > 0 {
			return pager
		}
		return "less"
	}
	if visual := os.get_env("VISUAL", context.temp_allocator); len(visual) > 0 {
		return visual
	}
	if editor := os.get_env("EDITOR", context.temp_allocator); len(editor) > 0 {
		return editor
	}
	return "vi"
}

panel_select_name :: proc(panel: ^Panel_State, name: string) -> bool {
	if panel == nil {
		return false
	}
	for file, index in panel.files {
		if file.name == name {
			panel.selected = index + 1
			return true
		}
	}
	return false
}
