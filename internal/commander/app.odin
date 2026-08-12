package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:internal/tui"

Run :: proc() {
	ui_context: tui.Context
	if !tui.init(&ui_context) {
		fmt.eprintln("Twin Commander wymaga interaktywnego terminala POSIX")
		return
	}
	defer tui.destroy(&ui_context)

	app: App_State
	defer app_destroy(&app)

	cwd, cwd_err := os.getwd(context.allocator)
	if cwd_err != nil {
		set_status(
			&app,
			fmt.aprintf("Nie można odczytać bieżącego katalogu: %s", os.error_string(cwd_err)),
		)
		cwd = strings.clone(".") or_else ""
	}
	defer delete(cwd)

	for index in 0 ..< len(app.panels) {
		if err := panel_load(&app.panels[index], cwd); err != nil {
			set_status(
				&app,
				fmt.aprintf("Nie można otworzyć katalogu: %s", os.error_string(err)),
			)
		}
	}
	if len(app.status) == 0 {
		set_status(&app, strings.clone("Gotowy") or_else "")
	}

	running := true
	for running {
		draw(&ui_context, &app)
		if !tui.present(&ui_context) {
			break
		}

		event, ok := tui.poll_event(&ui_context)
		if !ok {
			continue
		}
		handle_event(&ui_context, &app, event, &running)
	}
}

handle_event :: proc(ctx: ^tui.Context, app: ^App_State, event: tui.Event, running: ^bool) {
	if event.kind == .Appearance {
		if event.appearance == .Light {
			app.theme_mode = .Light
		} else if event.appearance == .Dark {
			app.theme_mode = .Dark
		}
		return
	}

	if app.overwrite_pending {
		handle_overwrite_event(ctx, app, event)
		return
	}

	#partial switch event.kind {
	case .Key:
		#partial switch event.key {
		case .Escape:
			running^ = false
		case .Tab:
			app.active_panel = 1 - app.active_panel
		case .Up:
			panel_move_selection(&app.panels[app.active_panel], -1)
		case .Down:
			panel_move_selection(&app.panels[app.active_panel], 1)
		case .Enter:
			enter_selected_directory(app)
		case .F5:
			copy_selected_file(ctx, app)
		}
	case .Text:
		if .Control in event.modifiers && event.text == 'c' {
			running^ = false
		}
	}
}

enter_selected_directory :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	target: string
	if panel.selected == 0 {
		target = filepath.join({panel.path, ".."}) or_else ""
	} else {
		file := panel.files[panel.selected - 1]
		if file.type != .Directory {
			set_status(app, fmt.aprintf("%s nie jest katalogiem", file.name))
			return
		}
		target = strings.clone(file.fullpath) or_else ""
	}
	defer delete(target)

	if len(target) == 0 {
		set_status(app, strings.clone("Nie udało się zbudować ścieżki") or_else "")
		return
	}
	if err := panel_load(panel, target); err != nil {
		set_status(app, fmt.aprintf("Nie można wejść do katalogu: %s", os.error_string(err)))
		return
	}
	set_status(app, fmt.aprintf("Katalog: %s", panel.path))
}
