package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:internal/fsops"
import "tc:internal/tui"

Copy_UI_Context :: struct {
	tui: ^tui.Context,
	app: ^App_State,
}

copy_selected_file :: proc(ctx: ^tui.Context, app: ^App_State) {
	file, destination_path, ok := selected_copy(app)
	defer delete(destination_path)
	if !ok {
		return
	}

	destination_info, destination_err := os.stat(destination_path, context.allocator)
	if destination_err == nil {
		os.file_info_delete(destination_info, context.allocator)
		app.overwrite_pending = true
		app.copy_name = file.name
		return
	}
	if destination_err != .Not_Exist {
		set_status(
			app,
			fmt.aprintf(
				"Nie można sprawdzić celu %s: %s",
				file.name,
				os.error_string(destination_err),
			),
		)
		return
	}

	perform_copy(ctx, app)
}

handle_overwrite_event :: proc(ctx: ^tui.Context, app: ^App_State, event: tui.Event) {
	confirm := event.kind == .Key && event.key == .Enter
	cancel := event.kind == .Key && event.key == .Escape
	if event.kind == .Text {
		confirm = event.text == 't' || event.text == 'T'
		cancel = event.text == 'n' || event.text == 'N'
	}
	if !confirm && !cancel {
		return
	}

	app.overwrite_pending = false
	app.copy_name = ""
	if cancel {
		set_status(app, strings.clone("Anulowano kopiowanie") or_else "")
		return
	}
	perform_copy(ctx, app)
}

selected_copy :: proc(app: ^App_State) -> (os.File_Info, string, bool) {
	source_panel := &app.panels[app.active_panel]
	destination_panel := &app.panels[1 - app.active_panel]
	if source_panel.selected == 0 {
		set_status(app, strings.clone("Wybierz plik do skopiowania") or_else "")
		return {}, "", false
	}

	file := source_panel.files[source_panel.selected - 1]
	if file.type != .Regular {
		set_status(app, fmt.aprintf("F5 kopiuje pliki; %s nie jest zwykłym plikiem", file.name))
		return {}, "", false
	}

	destination_path := filepath.join({destination_panel.path, file.name}) or_else ""
	if len(destination_path) == 0 {
		set_status(app, strings.clone("Nie udało się zbudować ścieżki docelowej") or_else "")
		return {}, destination_path, false
	}
	if file.fullpath == destination_path {
		set_status(app, strings.clone("Źródło i cel są tym samym plikiem") or_else "")
		return {}, destination_path, false
	}
	return file, destination_path, true
}

perform_copy :: proc(ctx: ^tui.Context, app: ^App_State) {
	file, destination_path, ok := selected_copy(app)
	defer delete(destination_path)
	if !ok {
		return
	}
	destination_panel := &app.panels[1 - app.active_panel]

	app.copying = true
	app.copy_name = file.name
	progress_context := Copy_UI_Context {
		tui = ctx,
		app = app,
	}
	progress_proc: fsops.Progress_Proc
	progress_data: rawptr
	if ctx != nil {
		progress_proc = on_copy_progress
		progress_data = rawptr(&progress_context)
	}
	copy_err := fsops.Copy_File(
		file.fullpath,
		destination_path,
		file.size,
		file.mode,
		progress_proc,
		progress_data,
	)
	app.copying = false
	app.copy_name = ""

	if copy_err != nil {
		set_status(
			app,
			fmt.aprintf("Błąd kopiowania %s: %s", file.name, os.error_string(copy_err)),
		)
		return
	}
	if refresh_err := panel_refresh(destination_panel); refresh_err != nil {
		set_status(
			app,
			fmt.aprintf(
				"Skopiowano %s, ale nie udało się odświeżyć panelu: %s",
				file.name,
				os.error_string(refresh_err),
			),
		)
		return
	}
	set_status(app, fmt.aprintf("Skopiowano %s do %s", file.name, destination_panel.path))
}

on_copy_progress :: proc(percent: int, user_data: rawptr) -> bool {
	progress_context := (^Copy_UI_Context)(user_data)
	progress_context.app.copy_percent = percent
	draw(progress_context.tui, progress_context.app)
	return tui.present(progress_context.tui)
}
