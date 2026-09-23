package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:pkg/tui"

begin_create_entry :: proc(app: ^App_State) {
	clear_edit_name(&app.create_name, &app.create_name_cursor)
	app.create_edit_pending = true
}

handle_create_edit_event :: proc(app: ^App_State, event: tui.Event) {
	switch handle_name_edit_input(&app.create_name, &app.create_name_cursor, event, true) {
	case .Cancel:
		clear_create_edit(app)
		set_status(app, strings.clone(tr("Anulowano tworzenie")) or_else "")
	case .Submit:
		if len(strings.trim_space(app.create_name)) == 0 || app.create_name == "." || app.create_name == ".." {
			set_status(app, strings.clone(tr("Podaj nazwę pliku lub ścieżkę katalogu")) or_else "")
			return
		}
		panel := &app.panels[app.active_panel]
		if panel.remote {
			remote_create_entry(app)
			return
		}
		path := filepath.join({panel.path, app.create_name}) or_else ""
		defer delete(path)
		if len(path) == 0 {
			set_status(app, strings.clone(tr("Nie udało się zbudować ścieżki")) or_else "")
			return
		}
		err: os.Error
		if strings.contains_rune(app.create_name, '/') {
			err = os.make_directory_all(path)
			if err == .Exist {
				info, stat_err := os.stat(path, context.allocator)
				if stat_err == nil {
					if info.type == .Directory do err = nil
					os.file_info_delete(info, context.allocator)
				}
			}
		} else {
			file: ^os.File
			file, err = os.open(path, os.O_WRONLY | os.O_CREATE | os.O_EXCL, os.Permissions_Default_File)
			if err == nil do err = os.close(file)
		}
		if err != nil {
			// mkdir -p may have created parents before encountering an error.
			refresh_create_panels(app)
			set_status(app, fmt.aprintf(tr("Nie można utworzyć %s: %s"), app.create_name, os.error_string(err)))
			return
		}
		refresh_err := refresh_create_panels(app)
		if refresh_err != nil {
			set_status(app, fmt.aprintf(tr("Utworzono %s, ale nie można odświeżyć paneli: %s"), app.create_name, os.error_string(refresh_err)))
		} else {
			// Select the created entry, or the first directory of a nested path.
			name := app.create_name
			for character, index in name {
				if character == '/' {
					name = name[:index]
					break
				}
			}
			panel_select_name(panel, name)
			set_status(app, fmt.aprintf(tr("Utworzono: %s"), app.create_name))
		}
		clear_create_edit(app)
	case .None:
	}
}

refresh_create_panels :: proc(app: ^App_State) -> os.Error {
	// Refresh both panels, including when the other one displays a newly
	// populated ancestor of a nested target.
	first_err := panel_refresh(&app.panels[app.active_panel])
	other_err := panel_refresh(&app.panels[1 - app.active_panel])
	if first_err != nil do return first_err
	return other_err
}

clear_create_edit :: proc(app: ^App_State) {
	app.create_edit_pending = false
	clear_edit_name(&app.create_name, &app.create_name_cursor)
}
