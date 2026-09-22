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
	cancelled: bool,
}

copy_selected_file :: proc(ctx: ^tui.Context, app: ^App_State) {
	entries, ok := copy_entries(app)
	defer delete(entries)
	if !ok do return
	if len(entries) == 1 {
		clear_copy_edit(app)
		app.copy_target_name = strings.clone(entries[0].name) or_else ""
		app.copy_name_cursor = len(app.copy_target_name)
		app.copy_edit_pending = true
		return
	}
	clear_copy_edit(app)
	prepare_copy(ctx, app, "")
}

handle_copy_edit_event :: proc(ctx: ^tui.Context, app: ^App_State, event: tui.Event) {
	switch handle_name_edit_input(&app.copy_target_name, &app.copy_name_cursor, event) {
	case .Cancel:
		clear_copy_edit(app)
		set_status(app, strings.clone(tr("Anulowano kopiowanie")) or_else "")
	case .Submit:
		if !target_name_is_valid(app.copy_target_name) {
			set_status(app, invalid_target_name_status())
			return
		}
		prepare_copy(ctx, app, app.copy_target_name)
	case .None:
	}
}

clear_copy_edit :: proc(app: ^App_State) {
	app.copy_edit_pending = false
	clear_edit_name(&app.copy_target_name, &app.copy_name_cursor)
}

prepare_copy :: proc(ctx: ^tui.Context, app: ^App_State, target_name: string) {
	entries, ok := copy_entries(app)
	defer delete(entries)
	if !ok do return
	for file in entries {
		destination_path, path_ok := copy_destination(app, file, target_name)
		if !path_ok {
			delete(destination_path)
			return
		}
		destination_info, destination_err := os.lstat(destination_path, context.allocator)
		delete(destination_path)
		if destination_err == nil {
			os.file_info_delete(destination_info, context.allocator)
			app.overwrite_pending = true
			app.copy_name = file.name
			if len(target_name) > 0 do app.copy_name = target_name
			app.copy_edit_pending = false
			app.pending_count = len(entries)
			return
		}
		if destination_err != .Not_Exist {
			set_status(app, fmt.aprintf(tr("Nie można sprawdzić celu %s: %s"), file.name, os.error_string(destination_err)))
			return
		}
	}
	app.copy_edit_pending = false
	perform_copy(ctx, app, false, target_name)
	clear_copy_edit(app)
}

handle_overwrite_event :: proc(ctx: ^tui.Context, app: ^App_State, event: tui.Event) {
	choice := confirmation_choice(event)
	if choice == .None do return
	app.overwrite_pending = false
	app.copy_name = ""
	app.pending_count = 0
	if choice == .No {
		clear_copy_edit(app)
		set_status(app, strings.clone(tr("Anulowano kopiowanie")) or_else "")
		return
	}
	perform_copy(ctx, app, true, app.copy_target_name)
	clear_copy_edit(app)
}

copy_entries :: proc(app: ^App_State) -> ([dynamic]os.File_Info, bool) {
	entries := panel_operation_entries(&app.panels[app.active_panel])
	if len(entries) == 0 {
		set_status(app, strings.clone(tr("Wybierz plik lub katalog do skopiowania")) or_else "")
		return entries, false
	}
	for file in entries {
		if file.type != .Regular && file.type != .Directory && file.type != .Symlink {
			set_status(app, fmt.aprintf(tr("F5 kopiuje pliki i katalogi; %s ma nieobsługiwany typ"), file.name))
			return entries, false
		}
	}
	return entries, true
}

copy_destination :: proc(app: ^App_State, file: os.File_Info, target_name: string) -> (string, bool) {
	destination_panel := &app.panels[1 - app.active_panel]
	if panel_is_archive(destination_panel) {
		archive_read_only_status(app)
		return "", false
	}
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
		set_status(app, strings.clone(tr("Nie można skopiować katalogu do jego wnętrza")) or_else "")
		return destination_path, false
	}
	return destination_path, true
}

perform_copy :: proc(ctx: ^tui.Context, app: ^App_State, replace: bool, target_name: string = "") {
	entries, ok := copy_entries(app)
	defer delete(entries)
	if !ok do return
	source_panel := &app.panels[app.active_panel]
	destination_panel := &app.panels[1 - app.active_panel]
	app.copying = true
	delete(app.operation_label)
	app.operation_label = strings.clone(tr("Kopiowanie")) or_else ""
	progress_context := Copy_UI_Context{tui = ctx, app = app}
	completed_count := 0
	skipped_count := 0
	for file, index in entries {
		destination_path, path_ok := copy_destination(app, file, target_name)
		if !path_ok {
			delete(destination_path)
			app.copying = false
			return
		}
		app.copy_name = file.name
		if len(target_name) > 0 do app.copy_name = target_name
		app.copy_percent = 0
		progress_proc: fsops.Progress_Proc
		progress_data: rawptr
		if ctx != nil {
			progress_proc = on_copy_progress
			progress_data = rawptr(&progress_context)
		}
		copy_err: os.Error
		for {
			progress_context.cancelled = false
			copy_err = fsops.Copy_Entry(file.fullpath, destination_path, replace, progress_proc, progress_data)
			if copy_err == nil {
				completed_count += 1
				break
			}
			if progress_context.cancelled {
				break
			}
			choice := ask_operation_error(ctx, app, file.name, copy_err)
			if choice == .Retry do continue
			if choice == .Skip {
				skipped_count += 1
				copy_err = nil
			}
			break
		}
		delete(destination_path)
		if copy_err != nil {
			app.copying = false
			app.copy_name = ""
			panel_refresh(destination_panel)
			if progress_context.cancelled {
				set_status(app, fmt.aprintf(tr("Anulowano kopiowanie po %d z %d elementów"), completed_count, len(entries)))
				return
			}
			set_status(app, fmt.aprintf(tr("Błąd kopiowania %s (%d/%d): %s"), file.name, index + 1, len(entries), os.error_string(copy_err)))
			return
		}
	}
	app.copying = false
	app.copy_name = ""
	panel_clear_marks(source_panel)
	if refresh_err := panel_refresh(destination_panel); refresh_err != nil {
		set_status(app, fmt.aprintf(tr("Skopiowano %d elementów, ale nie udało się odświeżyć panelu"), len(entries)))
		return
	}
	if skipped_count > 0 {
		set_status(app, fmt.aprintf(tr("Skopiowano %d, pominięto %d elementów"), completed_count, skipped_count))
	} else {
		set_status(app, fmt.aprintf(tr("Skopiowano %d elementów do %s"), completed_count, destination_panel.path))
	}
}

on_copy_progress :: proc(percent: int, user_data: rawptr) -> bool {
	progress_context := (^Copy_UI_Context)(user_data)
	progress_context.app.copy_percent = percent
	draw(progress_context.tui, progress_context.app)
	if !tui.present(progress_context.tui) do return false
	if operation_cancel_requested(progress_context.tui) {
		progress_context.cancelled = true
		return false
	}
	return true
}
