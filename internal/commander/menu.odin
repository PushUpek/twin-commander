package commander

import "tc:internal/tui"

USER_MENU_ITEMS: [8]string = {
	"Wykonaj polecenie",
	"Otwórz powłokę",
	"Kopiuj w tle",
	"Kolejka operacji",
	"Oblicz rozmiar",
	"Właściwości",
	"Zakładki",
	"Wyszukiwanie",
}

MAIN_MENU_ITEMS: [12]string = {
	"Wyszukiwanie",
	"Zakładki",
	"Porównaj panele",
	"Właściwości",
	"Oblicz rozmiar",
	"Utwórz link",
	"Suma SHA-256",
	"Kopiuj w tle",
	"Kolejka operacji",
	"Wykonaj polecenie",
	"Otwórz powłokę",
	"Pomoc",
}

begin_menu :: proc(app: ^App_State, kind: Menu_Kind) {
	app.menu_kind = kind
	app.menu_selected = 0
}

handle_menu_event :: proc(ctx: ^tui.Context, app: ^App_State, event: tui.Event, running: ^bool) {
	if event.kind != .Key do return
	count := len(MAIN_MENU_ITEMS)
	if app.menu_kind == .User do count = len(USER_MENU_ITEMS)
	#partial switch event.key {
	case .Escape: app.menu_kind = .None
	case .Up: app.menu_selected = max(app.menu_selected - 1, 0)
	case .Down: app.menu_selected = min(app.menu_selected + 1, count - 1)
	case .Home: app.menu_selected = 0
	case .End: app.menu_selected = count - 1
	case .Enter:
		kind := app.menu_kind
		selection := app.menu_selected
		app.menu_kind = .None
		activate_menu_item(ctx, app, running, kind, selection)
	case:
	}
}

activate_menu_item :: proc(ctx: ^tui.Context, app: ^App_State, running: ^bool, kind: Menu_Kind, selection: int) {
	if kind == .User {
		switch selection {
		case 0: begin_command(app)
		case 1: open_shell(ctx, app, running)
		case 2: enqueue_copy_jobs(app)
		case 3: begin_background_jobs(app)
		case 4: calculate_selected_size(app)
		case 5: begin_properties(app)
		case 6: begin_bookmarks(app)
		case 7: begin_search(app)
		}
		return
	}
	switch selection {
	case 0: begin_search(app)
	case 1: begin_bookmarks(app)
	case 2: compare_panels(app)
	case 3: begin_properties(app)
	case 4: calculate_selected_size(app)
	case 5: begin_link(app)
	case 6: begin_checksum(app)
	case 7: enqueue_copy_jobs(app)
	case 8: begin_background_jobs(app)
	case 9: begin_command(app)
	case 10: open_shell(ctx, app, running)
	case 11: app.help_pending = true
	}
}

menu_item :: proc(kind: Menu_Kind, index: int) -> string {
	if kind == .User {
		if index >= 0 && index < len(USER_MENU_ITEMS) do return USER_MENU_ITEMS[index]
	} else {
		if index >= 0 && index < len(MAIN_MENU_ITEMS) do return MAIN_MENU_ITEMS[index]
	}
	return ""
}
