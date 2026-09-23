package commander

import "core:fmt"
import "core:os"
import "core:strings"
import "tc:pkg/tui"

begin_command :: proc(app: ^App_State) {
	clear_edit_name(&app.command_text, &app.command_cursor)
	app.command_edit_pending = true
}

handle_command_event :: proc(ctx: ^tui.Context, app: ^App_State, event: tui.Event, running: ^bool) {
	switch handle_name_edit_input(&app.command_text, &app.command_cursor, event, true) {
	case .Cancel:
		app.command_edit_pending = false
	case .Submit:
		if len(strings.trim_space(app.command_text)) == 0 do return
		app.command_edit_pending = false
		run_terminal_process(ctx, app, []string{shell_program(), "-c", app.command_text}, running, false)
	case .None:
	}
}

open_shell :: proc(ctx: ^tui.Context, app: ^App_State, running: ^bool) {
	run_terminal_process(ctx, app, []string{shell_program()}, running, true)
}

shell_program :: proc() -> string {
	if shell := os.get_env("SHELL", context.temp_allocator); len(shell) > 0 do return shell
	return "/bin/sh"
}

run_terminal_process :: proc(
	ctx: ^tui.Context,
	app: ^App_State,
	command: []string,
	running: ^bool,
	interactive: bool,
) {
	panel := &app.panels[app.active_panel]
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
	if !interactive && start_err == nil && wait_err == nil {
		fmt.print("\n")
		fmt.printf(tr("Polecenie zakończone (kod %d). Naciśnij Enter, aby wrócić do paneli."), state.exit_code)
		fmt.print("\n")
		wait_for_enter()
	}
	if !tui.resume(ctx) {
		if running != nil do running^ = false
		return
	}
	for index in 0 ..< len(app.panels) do panel_refresh(&app.panels[index])
	if start_err != nil {
		set_status(app, fmt.aprintf(tr("Nie można uruchomić powłoki: %s"), os.error_string(start_err)))
	} else if wait_err != nil {
		set_status(app, fmt.aprintf(tr("Błąd powłoki: %s"), os.error_string(wait_err)))
	} else if !state.success || state.exit_code != 0 {
		set_status(app, fmt.aprintf(tr("Polecenie zakończyło się kodem %d"), state.exit_code))
	} else if interactive {
		set_status(app, strings.clone(tr("Zamknięto powłokę")) or_else "")
	} else {
		set_status(app, fmt.aprintf(tr("Polecenie wykonane (kod %d)"), state.exit_code))
	}
}

wait_for_enter :: proc() {
	buffer: [1]byte
	for {
		n, err := os.read(os.stdin, buffer[:])
		if err != nil || n == 0 || buffer[0] == '\n' || buffer[0] == '\r' do return
	}
}
