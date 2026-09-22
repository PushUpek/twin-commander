package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:internal/tui"

begin_link :: proc(app: ^App_State, hard := false) {
	panel := &app.panels[app.active_panel]
	if panel_is_archive(panel) {
		archive_read_only_status(app)
		return
	}
	if panel.selected <= 0 || panel.selected > len(panel.files) {
		set_status(app, strings.clone(tr("Wybierz plik lub katalog")) or_else "")
		return
	}
	file := panel.files[panel.selected - 1]
	delete(app.link_source)
	delete(app.link_name)
	app.link_source = strings.clone(file.fullpath) or_else ""
	app.link_name = strings.clone(file.name) or_else ""
	app.link_name_cursor = len(app.link_name)
	app.link_hard = hard
	app.link_edit_pending = true
}

handle_link_event :: proc(app: ^App_State, event: tui.Event) {
	if event.kind == .Key && event.key == .Tab {
		app.link_hard = !app.link_hard
		return
	}
	switch handle_name_edit_input(&app.link_name, &app.link_name_cursor, event) {
	case .Cancel: app.link_edit_pending = false
	case .Submit: create_link(app)
	case .None:
	}
}

create_link :: proc(app: ^App_State) -> bool {
	name := strings.trim_space(app.link_name)
	if len(name) == 0 || filepath.base(name) != name {
		set_status(app, strings.clone(tr("Podaj nazwę linku bez separatora katalogów")) or_else "")
		return false
	}
	destination_panel := &app.panels[1 - app.active_panel]
	if panel_is_archive(destination_panel) {
		archive_read_only_status(app)
		return false
	}
	destination := filepath.join({destination_panel.path, name}) or_else ""
	defer delete(destination)
	if len(destination) == 0 do return false
	err: os.Error
	if app.link_hard {
		err = os.link(app.link_source, destination)
	} else {
		err = os.symlink(app.link_source, destination)
	}
	if err != nil {
		set_status(app, fmt.aprintf(tr("Nie można utworzyć linku: %s"), os.error_string(err)))
		return false
	}
	app.link_edit_pending = false
	panel_refresh(destination_panel)
	kind := tr("symboliczny")
	if app.link_hard do kind = tr("twardy")
	set_status(app, fmt.aprintf(tr("Utworzono link %s: %s"), kind, name))
	return true
}
