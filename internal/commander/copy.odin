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
	source_panel := &app.panels[app.active_panel]
	destination_panel := &app.panels[1 - app.active_panel]
	if source_panel.selected == 0 {
		set_status(app, strings.clone("Wybierz plik do skopiowania") or_else "")
		return
	}

	file := source_panel.files[source_panel.selected - 1]
	if file.type != .Regular {
		set_status(app, fmt.aprintf("F5 kopiuje pliki; %s nie jest zwykłym plikiem", file.name))
		return
	}

	destination_path := filepath.join({destination_panel.path, file.name}) or_else ""
	defer delete(destination_path)
	if len(destination_path) == 0 {
		set_status(app, strings.clone("Nie udało się zbudować ścieżki docelowej") or_else "")
		return
	}
	if file.fullpath == destination_path {
		set_status(app, strings.clone("Źródło i cel są tym samym plikiem") or_else "")
		return
	}

	app.copying = true
	app.copy_name = file.name
	progress_context := Copy_UI_Context {
		tui = ctx,
		app = app,
	}
	copy_err := fsops.Copy_File(
		file.fullpath,
		destination_path,
		file.size,
		file.mode,
		on_copy_progress,
		rawptr(&progress_context),
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
