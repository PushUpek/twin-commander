package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import "tc:internal/tui"

Run :: proc() {
	app: App_State
	defer app_destroy(&app)
	if mode, ok := theme_mode_override(); ok {
		app.theme_mode = mode
		app.theme_overridden = true
	} else if system_mode, system_ok := system_theme_mode(); system_ok {
		app.theme_mode = system_mode
	}
	if !set_theme_mode(&app, app.theme_mode) {
		fmt.eprintln("Nie można wczytać motywu z katalogu config/themes")
		return
	}
	last_system_theme_check := time.tick_now()

	ui_context: tui.Context
	if !tui.init(&ui_context) {
		fmt.eprintln("Twin Commander wymaga interaktywnego terminala POSIX")
		return
	}
	defer tui.destroy(&ui_context)

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
		if !app.theme_overridden && time.tick_since(last_system_theme_check) >= 2 * time.Second {
			if mode, ok := system_theme_mode(); ok {
				set_theme_mode(&app, mode)
			}
			last_system_theme_check = time.tick_now()
		}
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
		apply_appearance(app, event.appearance)
		return
	}

	if app.overwrite_pending {
		handle_overwrite_event(ctx, app, event)
		return
	}
	if app.move_pending {
		handle_move_overwrite_event(app, event)
		return
	}
	if app.delete_pending {
		handle_delete_event(app, event)
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
		case .F3:
			open_selected_file(ctx, app, .View, running)
		case .F4:
			open_selected_file(ctx, app, .Edit, running)
		case .F5:
			copy_selected_file(ctx, app)
		case .F6:
			move_selected_entry(app)
		case .F8:
			delete_selected_entry(app)
		}
	case .Text:
		if .Control in event.modifiers && event.text == 'c' {
			running^ = false
		} else if event.text == ' ' {
			panel_toggle_mark(&app.panels[app.active_panel])
		}
	}
}

apply_appearance :: proc(app: ^App_State, appearance: tui.Appearance) {
	if app == nil || app.theme_overridden {
		return
	}
	#partial switch appearance {
	case .Light:
		set_theme_mode(app, .Light)
	case .Dark:
		set_theme_mode(app, .Dark)
	}
}

set_theme_mode :: proc(app: ^App_State, mode: Theme_Mode) -> bool {
	if app == nil {
		return false
	}
	if app.theme_mode == mode && len(app.theme.name) > 0 {
		return true
	}
	theme, ok := load_theme(mode, context.allocator)
	if !ok {
		return false
	}
	destroy_theme(&app.theme)
	app.theme = theme
	app.theme_mode = mode
	return true
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
