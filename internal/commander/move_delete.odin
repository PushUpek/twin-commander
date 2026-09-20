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

move_selected_entry :: proc(app: ^App_State, ctx: ^tui.Context = nil) {
	entries, ok := move_entries(app)
	defer delete(entries)
	if !ok do return
	if len(entries) == 1 {
		delete(app.move_name)
		app.move_name = strings.clone(entries[0].name) or_else ""
		app.move_name_cursor = len(app.move_name)
		app.move_edit_pending = true
		return
	}
	clear_move_edit(app)
	prepare_move(app, "", ctx)
}

handle_move_edit_event :: proc(app: ^App_State, event: tui.Event, ctx: ^tui.Context = nil) {
	switch handle_name_edit_input(&app.move_name, &app.move_name_cursor, event) {
	case .Cancel:
		clear_move_edit(app)
		set_status(app, strings.clone(tr("Anulowano przenoszenie")) or_else "")
	case .Submit:
		if !target_name_is_valid(app.move_name) {
			set_status(app, invalid_target_name_status())
			return
		}
		prepare_move(app, app.move_name, ctx)
	case .None:
	}
}

clear_move_edit :: proc(app: ^App_State) {
	app.move_edit_pending = false
	clear_edit_name(&app.move_name, &app.move_name_cursor)
}

prepare_move :: proc(app: ^App_State, target_name: string, ctx: ^tui.Context = nil) {
	entries, ok := move_entries(app)
	defer delete(entries)
	if !ok do return
	for file in entries {
		destination_path, path_ok := move_destination(app, file, target_name)
		if !path_ok {
			delete(destination_path)
			return
		}
		destination_info, destination_err := os.lstat(destination_path, context.allocator)
		if destination_err == nil {
			os.file_info_delete(destination_info, context.allocator)
			app.move_pending = true
			app.move_edit_pending = false
			app.pending_name = file.name
			if len(target_name) > 0 do app.pending_name = target_name
			app.pending_count = len(entries)
			delete(destination_path)
			return
		}
		delete(destination_path)
		if destination_err != .Not_Exist {
			set_status(app, fmt.aprintf(tr("Nie można sprawdzić celu %s: %s"), file.name, os.error_string(destination_err)))
			return
		}
	}
	app.move_edit_pending = false
	perform_move(app, false, target_name, ctx)
	clear_move_edit(app)
}

handle_move_overwrite_event :: proc(app: ^App_State, event: tui.Event, ctx: ^tui.Context = nil) {
	choice := confirmation_choice(event)
	if choice == .None do return
	app.move_pending = false
	app.pending_name = ""
	app.pending_count = 0
	if choice == .No {
		clear_move_edit(app)
		set_status(app, strings.clone(tr("Anulowano przenoszenie")) or_else "")
		return
	}
	perform_move(app, true, app.move_name, ctx)
	clear_move_edit(app)
}

move_entries :: proc(app: ^App_State) -> ([dynamic]os.File_Info, bool) {
	entries := panel_operation_entries(&app.panels[app.active_panel])
	if len(entries) == 0 {
		set_status(app, strings.clone(tr("Wybierz plik lub katalog do przeniesienia")) or_else "")
		return entries, false
	}
	for file in entries {
		if file.type != .Regular && file.type != .Directory && file.type != .Symlink {
			set_status(app, fmt.aprintf(tr("F6 przenosi pliki i katalogi; %s ma nieobsługiwany typ"), file.name))
			return entries, false
		}
	}
	return entries, true
}

move_destination :: proc(app: ^App_State, file: os.File_Info, target_name: string) -> (string, bool) {
	destination_panel := &app.panels[1 - app.active_panel]
	name := file.name
	if len(target_name) > 0 do name = target_name
	destination_path := filepath.join({destination_panel.path, name}) or_else ""
	if len(destination_path) == 0 {
		set_status(app, strings.clone(tr("Nie udało się zbudować ścieżki docelowej")) or_else "")
		return destination_path, false
	}
	if file.fullpath == destination_path {
		set_status(app, strings.clone(tr("Źródło i cel są tym samym elementem")) or_else "")
		return destination_path, false
	}
	if file.type == .Directory && path_is_inside(destination_panel.path, file.fullpath) {
		set_status(app, strings.clone(tr("Nie można przenieść katalogu do jego wnętrza")) or_else "")
		return destination_path, false
	}
	return destination_path, true
}

path_is_inside :: proc(path, directory: string) -> bool {
	if len(path) <= len(directory) || !strings.has_prefix(path, directory) do return false
	return os.is_path_separator(path[len(directory)])
}

perform_move :: proc(app: ^App_State, replace: bool, target_name: string = "", ctx: ^tui.Context = nil) {
	entries, ok := move_entries(app)
	defer delete(entries)
	if !ok do return
	source_panel := &app.panels[app.active_panel]
	destination_panel := &app.panels[1 - app.active_panel]
	entry_count := len(entries)
	completed_count := 0
	skipped_count := 0
	cancelled := false
	progress_context := Copy_UI_Context{tui = ctx, app = app}
	delete(app.operation_label)
	app.operation_label = strings.clone(tr("Przenoszenie")) or_else ""
	for file, index in entries {
		if operation_cancel_requested(ctx) {
			cancelled = true
			break
		}
		destination_path, path_ok := move_destination(app, file, target_name)
		if !path_ok {
			delete(destination_path)
			return
		}
		name := strings.clone(file.name) or_else ""
		move_err: os.Error
		for {
			progress_context.cancelled = false
			app.copying = true
			app.copy_name = file.name
			app.copy_percent = 0
			progress_proc: fsops.Progress_Proc
			progress_data: rawptr
			if ctx != nil {
				progress_proc = on_copy_progress
				progress_data = rawptr(&progress_context)
			}
			move_err = fsops.Move_Entry(file.fullpath, destination_path, replace, progress_proc, progress_data)
			app.copying = false
			if move_err == nil {
				completed_count += 1
				break
			}
			if progress_context.cancelled do break
			choice := ask_operation_error(ctx, app, file.name, move_err)
			if choice == .Retry do continue
			if choice == .Skip {
				skipped_count += 1
				move_err = nil
			}
			break
		}
		delete(destination_path)
		if move_err != nil {
			panel_refresh(source_panel)
			panel_refresh(destination_panel)
			if progress_context.cancelled {
				set_status(app, fmt.aprintf(tr("Anulowano przenoszenie po %d z %d elementów"), completed_count, entry_count))
			} else {
				set_status(app, fmt.aprintf(tr("Błąd przenoszenia %s (%d/%d): %s"), name, index + 1, entry_count, os.error_string(move_err)))
			}
			delete(name)
			return
		}
		delete(name)
	}
	source_refresh_err := panel_refresh(source_panel)
	destination_refresh_err := panel_refresh(destination_panel)
	if source_refresh_err != nil || destination_refresh_err != nil {
		set_status(app, fmt.aprintf(tr("Przeniesiono %d elementów, ale nie udało się odświeżyć paneli"), entry_count))
		return
	}
	if cancelled {
		set_status(app, fmt.aprintf(tr("Anulowano przenoszenie po %d z %d elementów"), completed_count, entry_count))
		return
	}
	if skipped_count > 0 {
		set_status(app, fmt.aprintf(tr("Przeniesiono %d, pominięto %d elementów"), completed_count, skipped_count))
	} else {
		set_status(app, fmt.aprintf(tr("Przeniesiono %d elementów do %s"), completed_count, destination_panel.path))
	}
}

delete_selected_entry :: proc(app: ^App_State) {
	entries, ok := delete_entries(app)
	defer delete(entries)
	if !ok do return
	app.delete_pending = true
	app.pending_name = entries[0].name
	app.pending_count = len(entries)
}

handle_delete_event :: proc(app: ^App_State, event: tui.Event, ctx: ^tui.Context = nil) {
	choice := confirmation_choice(event)
	if choice == .None do return
	app.delete_pending = false
	app.pending_name = ""
	app.pending_count = 0
	if choice == .No {
		set_status(app, strings.clone(tr("Anulowano usuwanie")) or_else "")
		return
	}
	perform_delete(app, ctx)
}

delete_entries :: proc(app: ^App_State) -> ([dynamic]os.File_Info, bool) {
	entries := panel_operation_entries(&app.panels[app.active_panel])
	if len(entries) == 0 {
		set_status(app, strings.clone(tr("Wybierz plik lub katalog do usunięcia")) or_else "")
		return entries, false
	}
	for file in entries {
		if file.type != .Regular && file.type != .Directory && file.type != .Symlink {
			set_status(app, fmt.aprintf(tr("F8 usuwa pliki i katalogi; %s ma nieobsługiwany typ"), file.name))
			return entries, false
		}
	}
	return entries, true
}

perform_delete :: proc(app: ^App_State, ctx: ^tui.Context = nil) {
	entries, ok := delete_entries(app)
	defer delete(entries)
	if !ok do return
	panel := &app.panels[app.active_panel]
	other_panel := &app.panels[1 - app.active_panel]
	refresh_other := panel.path == other_panel.path
	entry_count := len(entries)
	completed_count := 0
	skipped_count := 0
	cancelled := false
	for file, index in entries {
		name := strings.clone(file.name) or_else ""
		if operation_cancel_requested(ctx) {
			cancelled = true
			delete(name)
			break
		}
		delete_err: os.Error
		for {
			delete_err = fsops.Delete_Entry(file.fullpath)
			if delete_err == nil {
				completed_count += 1
				break
			}
			choice := ask_operation_error(ctx, app, name, delete_err)
			if choice == .Retry do continue
			if choice == .Skip {
				skipped_count += 1
				delete_err = nil
			}
			break
		}
		if delete_err != nil {
			panel_refresh(panel)
			if refresh_other do panel_refresh(other_panel)
			set_status(app, fmt.aprintf(tr("Błąd usuwania %s (%d/%d): %s"), name, index + 1, entry_count, os.error_string(delete_err)))
			delete(name)
			return
		}
		delete(name)
	}
	if refresh_err := panel_refresh(panel); refresh_err != nil {
		set_status(app, fmt.aprintf(tr("Usunięto %d elementów, ale nie udało się odświeżyć panelu"), entry_count))
		return
	}
	if refresh_other {
		if refresh_err := panel_refresh(other_panel); refresh_err != nil {
			set_status(app, fmt.aprintf(tr("Usunięto %d elementów, ale nie udało się odświeżyć drugiego panelu"), entry_count))
			return
		}
	}
	if cancelled {
		set_status(app, fmt.aprintf(tr("Anulowano usuwanie po %d z %d elementów"), completed_count, entry_count))
		return
	}
	if skipped_count > 0 {
		set_status(app, fmt.aprintf(tr("Usunięto %d, pominięto %d elementów"), completed_count, skipped_count))
	} else {
		set_status(app, fmt.aprintf(tr("Usunięto %d elementów"), completed_count))
	}
}

confirmation_choice :: proc(event: tui.Event) -> Confirmation_Choice {
	if event.kind == .Key {
		if event.key == .Enter do return .Yes
		if event.key == .Escape do return .No
	}
	if event.kind == .Text {
		switch event.text {
		case 't', 'T': return .Yes
		case 'n', 'N': return .No
		case 'w', 'W': return .All
		}
	}
	return .None
}
