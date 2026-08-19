package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:internal/fsops"
import "tc:internal/tui"

Confirmation_Choice :: enum {
	None,
	Yes,
	No,
	All,
}

move_selected_entry :: proc(app: ^App_State) {
	file, destination_path, ok := selected_move(app)
	defer delete(destination_path)
	if !ok {
		return
	}

	destination_info, destination_err := os.stat(destination_path, context.allocator)
	if destination_err == nil {
		os.file_info_delete(destination_info, context.allocator)
		app.move_pending = true
		app.pending_name = file.name
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

	perform_move(app, false)
}

handle_move_overwrite_event :: proc(app: ^App_State, event: tui.Event) {
	choice := confirmation_choice(event)
	if choice == .None {
		return
	}

	app.move_pending = false
	app.pending_name = ""
	if choice == .No {
		set_status(app, strings.clone("Anulowano przenoszenie") or_else "")
		return
	}
	perform_move(app, true)
}

selected_move :: proc(app: ^App_State) -> (os.File_Info, string, bool) {
	source_panel := &app.panels[app.active_panel]
	destination_panel := &app.panels[1 - app.active_panel]
	if source_panel.selected == 0 {
		set_status(app, strings.clone("Wybierz plik lub katalog do przeniesienia") or_else "")
		return {}, "", false
	}

	file := source_panel.files[source_panel.selected - 1]
	if file.type != .Regular && file.type != .Directory {
		set_status(
			app,
			fmt.aprintf("F6 przenosi pliki i katalogi; %s ma nieobsługiwany typ", file.name),
		)
		return {}, "", false
	}

	destination_path := filepath.join({destination_panel.path, file.name}) or_else ""
	if len(destination_path) == 0 {
		set_status(app, strings.clone("Nie udało się zbudować ścieżki docelowej") or_else "")
		return {}, destination_path, false
	}
	if file.fullpath == destination_path {
		set_status(app, strings.clone("Źródło i cel są tym samym elementem") or_else "")
		return {}, destination_path, false
	}
	if file.type == .Directory && path_is_inside(destination_panel.path, file.fullpath) {
		set_status(
			app,
			strings.clone("Nie można przenieść katalogu do jego wnętrza") or_else "",
		)
		return {}, destination_path, false
	}
	return file, destination_path, true
}

path_is_inside :: proc(path, directory: string) -> bool {
	if len(path) <= len(directory) || !strings.has_prefix(path, directory) {
		return false
	}
	return os.is_path_separator(path[len(directory)])
}

perform_move :: proc(app: ^App_State, replace: bool) {
	file, destination_path, ok := selected_move(app)
	defer delete(destination_path)
	if !ok {
		return
	}
	source_panel := &app.panels[app.active_panel]
	destination_panel := &app.panels[1 - app.active_panel]
	name := strings.clone(file.name) or_else ""
	defer delete(name)

	if move_err := fsops.Move_Entry(file.fullpath, destination_path, replace); move_err != nil {
		set_status(app, fmt.aprintf("Błąd przenoszenia %s: %s", name, os.error_string(move_err)))
		return
	}

	source_refresh_err := panel_refresh(source_panel)
	destination_refresh_err := panel_refresh(destination_panel)
	if source_refresh_err != nil || destination_refresh_err != nil {
		set_status(
			app,
			fmt.aprintf("Przeniesiono %s, ale nie udało się odświeżyć paneli", name),
		)
		return
	}
	set_status(app, fmt.aprintf("Przeniesiono %s do %s", name, destination_panel.path))
}

delete_selected_entry :: proc(app: ^App_State) {
	file, ok := selected_delete(app)
	if !ok {
		return
	}
	app.delete_pending = true
	app.pending_name = file.name
}

handle_delete_event :: proc(app: ^App_State, event: tui.Event) {
	choice := confirmation_choice(event)
	if choice == .None {
		return
	}

	app.delete_pending = false
	app.pending_name = ""
	if choice == .No {
		set_status(app, strings.clone("Anulowano usuwanie") or_else "")
		return
	}
	perform_delete(app)
}

selected_delete :: proc(app: ^App_State) -> (os.File_Info, bool) {
	panel := &app.panels[app.active_panel]
	if panel.selected == 0 {
		set_status(app, strings.clone("Wybierz plik lub katalog do usunięcia") or_else "")
		return {}, false
	}
	file := panel.files[panel.selected - 1]
	if file.type != .Regular && file.type != .Directory {
		set_status(
			app,
			fmt.aprintf("F8 usuwa pliki i katalogi; %s ma nieobsługiwany typ", file.name),
		)
		return {}, false
	}
	return file, true
}

perform_delete :: proc(app: ^App_State) {
	file, ok := selected_delete(app)
	if !ok {
		return
	}
	panel := &app.panels[app.active_panel]
	other_panel := &app.panels[1 - app.active_panel]
	refresh_other := panel.path == other_panel.path
	name := strings.clone(file.name) or_else ""
	defer delete(name)
	if delete_err := fsops.Delete_Entry(file.fullpath); delete_err != nil {
		set_status(app, fmt.aprintf("Błąd usuwania %s: %s", name, os.error_string(delete_err)))
		return
	}
	if refresh_err := panel_refresh(panel); refresh_err != nil {
		set_status(app, fmt.aprintf("Usunięto %s, ale nie udało się odświeżyć panelu", name))
		return
	}
	if refresh_other {
		if refresh_err := panel_refresh(other_panel); refresh_err != nil {
			set_status(
				app,
				fmt.aprintf(
					"Usunięto %s, ale nie udało się odświeżyć drugiego panelu",
					name,
				),
			)
			return
		}
	}
	set_status(app, fmt.aprintf("Usunięto %s", name))
}

confirmation_choice :: proc(event: tui.Event) -> Confirmation_Choice {
	if event.kind == .Key {
		if event.key == .Enter {
			return .Yes
		}
		if event.key == .Escape {
			return .No
		}
	}
	if event.kind == .Text {
		switch event.text {
		case 't', 'T':
			return .Yes
		case 'n', 'N':
			return .No
		case 'w', 'W':
			return .All
		}
	}
	return .None
}
