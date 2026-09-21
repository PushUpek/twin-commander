package commander

import "core:fmt"
import "core:strings"
import "tc:internal/tui"

begin_bookmarks :: proc(app: ^App_State) {
	app.bookmarks_pending = true
	app.bookmark_selected = clamp(app.bookmark_selected, 0, max(len(app.bookmarks) - 1, 0))
}

handle_bookmarks_event :: proc(app: ^App_State, event: tui.Event) {
	if event.kind == .Key {
		#partial switch event.key {
		case .Escape:
			app.bookmarks_pending = false
		case .Up:
			app.bookmark_selected = max(app.bookmark_selected - 1, 0)
		case .Down:
			app.bookmark_selected = min(app.bookmark_selected + 1, max(len(app.bookmarks) - 1, 0))
		case .Home:
			app.bookmark_selected = 0
		case .End:
			app.bookmark_selected = max(len(app.bookmarks) - 1, 0)
		case .Enter:
			open_selected_bookmark(app)
		case:
		}
		return
	}
	if event.kind != .Text || event.modifiers != {} do return
	switch event.text {
	case 'a', 'A': add_current_bookmark(app)
	case 'd', 'D': remove_selected_bookmark(app)
	case:
	}
}

add_current_bookmark :: proc(app: ^App_State) -> bool {
	path := app.panels[app.active_panel].path
	for existing in app.bookmarks {
		if existing == path {
			set_status(app, strings.clone(tr("Ten katalog jest już w zakładkach")) or_else "")
			return false
		}
	}
	append(&app.bookmarks, strings.clone(path) or_else "")
	app.bookmark_selected = len(app.bookmarks) - 1
	set_status(app, fmt.aprintf(tr("Dodano zakładkę: %s"), path))
	return true
}

remove_selected_bookmark :: proc(app: ^App_State) -> bool {
	if app.bookmark_selected < 0 || app.bookmark_selected >= len(app.bookmarks) do return false
	path := app.bookmarks[app.bookmark_selected]
	status := fmt.aprintf(tr("Usunięto zakładkę: %s"), path)
	delete(path)
	ordered_remove(&app.bookmarks, app.bookmark_selected)
	app.bookmark_selected = min(app.bookmark_selected, max(len(app.bookmarks) - 1, 0))
	set_status(app, status)
	return true
}

open_selected_bookmark :: proc(app: ^App_State) {
	if app.bookmark_selected < 0 || app.bookmark_selected >= len(app.bookmarks) do return
	path := app.bookmarks[app.bookmark_selected]
	if err := panel_load(&app.panels[app.active_panel], path); err != nil {
		set_status(app, fmt.aprintf(tr("Nie można otworzyć zakładki: %s"), path))
		return
	}
	app.bookmarks_pending = false
	set_status(app, fmt.aprintf(tr("Zakładka: %s"), path))
}
