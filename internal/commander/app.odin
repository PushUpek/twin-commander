package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import "tc:internal/tui"

Run :: proc() {
	locale_init()
	defer locale_destroy()
	app: App_State
	defer app_destroy(&app)
	if mode, ok := theme_mode_override(); ok {
		app.theme_mode = mode
		app.theme_overridden = true
	} else if system_mode, system_ok := system_theme_mode(); system_ok {
		app.theme_mode = system_mode
	}
	if !set_theme_mode(&app, app.theme_mode) {
		fmt.eprintln(tr("Nie można wczytać motywu z katalogu config/themes"))
		return
	}
	associations_load(&app)
	last_system_theme_check := time.tick_now()

	ui_context: tui.Context
	if !tui.init(&ui_context) {
		fmt.eprintln(tr("Twin Commander wymaga interaktywnego terminala POSIX"))
		return
	}
	defer tui.destroy(&ui_context)

	cwd, cwd_err := os.getwd(context.allocator)
	if cwd_err != nil {
		set_status(
			&app,
			fmt.aprintf(tr("Nie można odczytać bieżącego katalogu: %s"), os.error_string(cwd_err)),
		)
		cwd = strings.clone(".") or_else ""
	}
	defer delete(cwd)

	for index in 0 ..< len(app.panels) {
		if err := panel_load(&app.panels[index], cwd); err != nil {
			set_status(
				&app,
				fmt.aprintf(tr("Nie można otworzyć katalogu: %s"), os.error_string(err)),
			)
		}
	}
	bookmarks_load(&app)
	if len(app.status) == 0 {
		set_status(&app, strings.clone(tr("Gotowy")) or_else "")
	}

	running := true
	for running {
		background_tick(&app)
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

		timeout_ms := -1
		if background_has_active_job(&app) do timeout_ms = 100
		event, ok := tui.poll_event(&ui_context, timeout_ms)
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

	if app.exit_pending {
		handle_exit_event(app, event, running)
		return
	}
	if app.help_pending {
		if event.kind == .Key && (event.key == .Escape || event.key == .Enter || event.key == .F1) do app.help_pending = false
		return
	}
	if app.menu_kind != .None {
		handle_menu_event(ctx, app, event, running)
		return
	}
	if app.command_edit_pending {
		handle_command_event(ctx, app, event, running)
		return
	}
	if app.viewer_pending {
		handle_viewer_event(ctx, app, event)
		return
	}
	if app.link_edit_pending {
		handle_link_event(app, event)
		return
	}
	if app.checksum_pending {
		handle_checksum_event(app, event)
		return
	}
	if app.background_pending {
		handle_background_event(app, event)
		return
	}
	if app.create_edit_pending {
		handle_create_edit_event(app, event)
		return
	}
	if app.filter_edit_pending {
		handle_filter_edit_event(app, event)
		return
	}
	if app.mark_edit_pending {
		handle_mark_edit_event(app, event)
		return
	}
	if app.search_edit_pending {
		handle_search_edit_event(app, event)
		return
	}
	if app.search_results_pending {
		handle_search_results_event(app, event)
		return
	}
	if app.properties_pending {
		handle_properties_event(app, event)
		return
	}
	if app.bookmarks_pending {
		handle_bookmarks_event(app, event)
		return
	}
	if app.overwrite_pending {
		handle_overwrite_event(ctx, app, event)
		return
	}
	if app.copy_edit_pending {
		handle_copy_edit_event(ctx, app, event)
		return
	}
	if app.move_edit_pending {
		handle_move_edit_event(app, event, ctx)
		return
	}
	if app.move_pending {
		handle_move_overwrite_event(app, event, ctx)
		return
	}
	if app.delete_pending {
		handle_delete_event(app, event, ctx)
		return
	}

	#partial switch event.kind {
	case .Key:
		#partial switch event.key {
		case .F1:
			app.help_pending = true
		case .F2:
			begin_menu(app, .User)
		case .F9:
			begin_menu(app, .Main)
		case .Escape:
			panel := &app.panels[app.active_panel]
			if len(panel.quick_search) > 0 {
				delete(panel.quick_search)
				panel.quick_search = ""
				set_status(app, strings.clone(tr("Wyczyszczono szybkie wyszukiwanie")) or_else "")
			} else {
				app.exit_pending = true
			}
		case .F10:
			app.exit_pending = true
		case .Tab:
			app.active_panel = 1 - app.active_panel
		case .Up:
			panel_move_selection(&app.panels[app.active_panel], -1)
		case .Down:
			panel_move_selection(&app.panels[app.active_panel], 1)
		case .Home:
			panel_select_edge(&app.panels[app.active_panel], false)
		case .End:
			panel_select_edge(&app.panels[app.active_panel], true)
		case .Page_Up:
			_, height := tui.size(ctx)
			panel_move_page(&app.panels[app.active_panel], -1, height - 5)
		case .Page_Down:
			_, height := tui.size(ctx)
			panel_move_page(&app.panels[app.active_panel], 1, height - 5)
		case .Left:
			navigate_history(app, -1)
		case .Right:
			navigate_history(app, 1)
		case .Backspace:
			if !panel_quick_search_backspace(&app.panels[app.active_panel]) {
				navigate_parent(app)
			}
		case .Enter:
			activate_selected(ctx, app, running)
		case .F3:
			begin_viewer(app)
		case .F4:
			if panel_is_archive(&app.panels[app.active_panel]) do archive_read_only_status(app)
			else do open_selected_file(ctx, app, .Edit, running)
		case .F5:
			copy_selected_file(ctx, app)
		case .F6:
			if panel_is_archive(&app.panels[app.active_panel]) do archive_read_only_status(app)
			else do move_selected_entry(app, ctx)
		case .F7:
			if .Alt in event.modifiers {
				begin_search(app)
			} else if panel_is_archive(&app.panels[app.active_panel]) {
				archive_read_only_status(app)
			} else {
				begin_create_entry(app)
			}
		case .F8:
			if panel_is_archive(&app.panels[app.active_panel]) do archive_read_only_status(app)
			else do delete_selected_entry(app)
		}
	case .Text:
		if .Control in event.modifiers && event.text == 'c' {
			running^ = false
		} else if .Control in event.modifiers && event.text == 'r' {
			refresh_active_panel(app)
		} else if .Control in event.modifiers && event.text == 's' {
			cycle_sort(app)
		} else if .Control in event.modifiers && event.text == 'f' {
			begin_filter_edit(app)
		} else if .Control in event.modifiers && event.text == 'd' {
			toggle_hidden(app)
		} else if .Control in event.modifiers && event.text == 'g' {
			begin_search(app)
		} else if .Control in event.modifiers && event.text == 'p' {
			begin_properties(app)
		} else if .Control in event.modifiers && event.text == 'b' {
			begin_bookmarks(app)
		} else if .Control in event.modifiers && event.text == 'q' {
			compare_panels(app)
		} else if .Control in event.modifiers && event.text == 'o' {
			open_shell(ctx, app, running)
		} else if .Control in event.modifiers && event.text == 'u' {
			calculate_selected_size(app)
		} else if .Control in event.modifiers && event.text == 'l' {
			begin_link(app)
		} else if .Control in event.modifiers && event.text == 'k' {
			begin_checksum(app)
		} else if .Control in event.modifiers && event.text == 'j' {
			enqueue_copy_jobs(app)
		} else if .Control in event.modifiers && event.text == 't' {
			begin_background_jobs(app)
		} else if event.modifiers == {} && len(app.panels[app.active_panel].quick_search) == 0 && (event.text == 'v' || event.text == 'V') {
			begin_viewer(app)
		} else if event.modifiers == {} && len(app.panels[app.active_panel].quick_search) == 0 && (event.text == 'e' || event.text == 'E') {
			if panel_is_archive(&app.panels[app.active_panel]) do archive_read_only_status(app)
			else do open_selected_file(ctx, app, .Edit, running)
		} else if event.text == ' ' {
			panel_toggle_mark(&app.panels[app.active_panel])
		} else if event.modifiers == {} && event.text == '/' {
			begin_filter_edit(app)
		} else if event.modifiers == {} && event.text == ':' {
			begin_command(app)
		} else if event.modifiers == {} && event.text == '+' {
			begin_mark_pattern(app, .Select)
		} else if event.modifiers == {} && event.text == '\\' {
			begin_mark_pattern(app, .Unselect)
		} else if event.modifiers == {} && event.text == '*' {
			panel_invert_marks(&app.panels[app.active_panel])
			set_status(app, strings.clone(tr("Odwrócono oznaczenie")) or_else "")
		} else if event.modifiers == {} && event.text >= ' ' {
			panel := &app.panels[app.active_panel]
			if panel_quick_search(panel, event.text) {
				set_status(app, fmt.aprintf(tr("Szybkie wyszukiwanie: %s"), panel.quick_search))
			} else {
				set_status(app, fmt.aprintf(tr("Brak nazwy zaczynającej się od: %s"), panel.quick_search))
			}
		}
	}
}

activate_selected :: proc(ctx: ^tui.Context, app: ^App_State, running: ^bool) {
	panel := &app.panels[app.active_panel]
	if panel.selected == 0 {
		enter_selected_directory(app)
		return
	}
	if panel.selected > len(panel.files) do return
	file := panel.files[panel.selected - 1]
	is_directory := file.type == .Directory
	if file.type == .Symlink {
		followed, err := os.stat(file.fullpath, context.temp_allocator)
		if err == nil {
			is_directory = followed.type == .Directory
			os.file_info_delete(followed, context.temp_allocator)
		}
	}
	if is_directory {
		enter_selected_directory(app)
	} else if open_archive(app, file.fullpath) {
		return
	} else if !open_associated_file(ctx, app, file.fullpath, running) {
		begin_viewer(app)
	}
}

handle_exit_event :: proc(app: ^App_State, event: tui.Event, running: ^bool) {
	choice := confirmation_choice(event)
	#partial switch choice {
	case .Yes:
		app.exit_pending = false
		running^ = false
	case .No:
		app.exit_pending = false
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
		if leave_archive(panel) {
			set_status(app, fmt.aprintf(tr("Katalog: %s"), panel.path))
			return
		}
		target = filepath.join({panel.path, ".."}) or_else ""
	} else {
		file := panel.files[panel.selected - 1]
		is_directory := file.type == .Directory
		if file.type == .Symlink {
			followed, follow_err := os.stat(file.fullpath, context.allocator)
			if follow_err == nil {
				is_directory = followed.type == .Directory
				os.file_info_delete(followed, context.allocator)
			}
		}
		if !is_directory {
			set_status(app, fmt.aprintf(tr("%s nie jest katalogiem"), file.name))
			return
		}
		target = strings.clone(file.fullpath) or_else ""
	}
	defer delete(target)

	if len(target) == 0 {
		set_status(app, strings.clone(tr("Nie udało się zbudować ścieżki")) or_else "")
		return
	}
	if err := panel_load(panel, target, !panel_is_archive(panel)); err != nil {
		set_status(app, fmt.aprintf(tr("Nie można wejść do katalogu: %s"), os.error_string(err)))
		return
	}
	set_status(app, fmt.aprintf(tr("Katalog: %s"), panel.path))
}
