package commander

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:pkg/fsops"
import "tc:pkg/tui"

refresh_active_panel :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	if err := panel_refresh(panel); err != nil {
		set_status(app, fmt.aprintf(tr("Nie można odświeżyć katalogu: %s"), os.error_string(err)))
		return
	}
	set_status(app, strings.clone(tr("Odświeżono panel")) or_else "")
}

toggle_hidden :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	panel.show_hidden = !panel.show_hidden
	refresh_active_panel(app)
	if panel.show_hidden {
		set_status(app, strings.clone(tr("Pokazano ukryte pliki")) or_else "")
	} else {
		set_status(app, strings.clone(tr("Ukryto pliki zaczynające się od kropki")) or_else "")
	}
}

cycle_sort :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	switch panel.sort_kind {
	case .Name:      panel.sort_kind = .Extension
	case .Extension: panel.sort_kind = .Size
	case .Size:      panel.sort_kind = .Modified
	case .Modified:
		panel.sort_kind = .Name
		panel.sort_reverse = !panel.sort_reverse
	}
	refresh_active_panel(app)
	set_status(app, fmt.aprintf(tr("Sortowanie: %s%s"), sort_label(panel.sort_kind), " ↓" if panel.sort_reverse else " ↑"))
}

sort_label :: proc(kind: fsops.Sort_Kind) -> string {
	switch kind {
	case .Name:      return tr("nazwa")
	case .Extension: return tr("rozszerzenie")
	case .Size:      return tr("rozmiar")
	case .Modified:  return tr("data modyfikacji")
	}
	return ""
}

begin_filter_edit :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	delete(app.filter_text)
	app.filter_text = strings.clone(panel.filter) or_else ""
	app.filter_cursor = len(app.filter_text)
	app.filter_edit_pending = true
}

handle_filter_edit_event :: proc(app: ^App_State, event: tui.Event) {
	switch handle_name_edit_input(&app.filter_text, &app.filter_cursor, event) {
	case .Cancel:
		app.filter_edit_pending = false
	case .Submit:
		panel := &app.panels[app.active_panel]
		delete(panel.filter)
		panel.filter = strings.clone(strings.trim_space(app.filter_text)) or_else ""
		app.filter_edit_pending = false
		refresh_active_panel(app)
		if len(panel.filter) == 0 {
			set_status(app, strings.clone(tr("Wyłączono filtr panelu")) or_else "")
		} else {
			set_status(app, fmt.aprintf(tr("Filtr panelu: %s"), panel.filter))
		}
	case .None:
	}
}

begin_mark_pattern :: proc(app: ^App_State, mode: Mark_Mode) {
	delete(app.mark_pattern)
	app.mark_pattern = strings.clone("*") or_else ""
	app.mark_pattern_cursor = len(app.mark_pattern)
	app.mark_mode = mode
	app.mark_edit_pending = true
}

handle_mark_edit_event :: proc(app: ^App_State, event: tui.Event) {
	switch handle_name_edit_input(&app.mark_pattern, &app.mark_pattern_cursor, event) {
	case .Cancel:
		app.mark_edit_pending = false
	case .Submit:
		pattern := strings.trim_space(app.mark_pattern)
		if len(pattern) == 0 do pattern = "*"
		panel := &app.panels[app.active_panel]
		if !panel_mark_pattern(panel, pattern, app.mark_mode == .Select) {
			set_status(app, fmt.aprintf(tr("Brak elementów pasujących do: %s"), pattern))
		} else if app.mark_mode == .Select {
			set_status(app, fmt.aprintf(tr("Oznaczono elementy: %s"), pattern))
		} else {
			set_status(app, fmt.aprintf(tr("Odznaczono elementy: %s"), pattern))
		}
		app.mark_edit_pending = false
	case .None:
	}
}

navigate_parent :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	if panel.remote {
		if remote_leave(panel) do set_status(app, fmt.aprintf(tr("Katalog: %s"), panel.path))
		return
	}
	if leave_archive(panel) {
		set_status(app, fmt.aprintf(tr("Katalog: %s"), panel.path))
		return
	}
	child_name := strings.clone(filepath.base(panel.path)) or_else ""
	defer delete(child_name)
	target := filepath.join({panel.path, ".."}) or_else ""
	defer delete(target)
	if err := panel_load(panel, target, !panel_is_archive(panel)); err != nil {
		set_status(app, fmt.aprintf(tr("Nie można wejść do katalogu: %s"), os.error_string(err)))
	} else {
		panel_select_name(panel, child_name)
		set_status(app, fmt.aprintf(tr("Katalog: %s"), panel.path))
	}
}

navigate_history :: proc(app: ^App_State, delta: int) {
	panel := &app.panels[app.active_panel]
	if panel_is_archive(panel) {
		set_status(app, strings.clone(tr("Historia katalogów jest wyłączona w archiwum")) or_else "")
		return
	}
	old_index := panel.history_index
	if err := panel_history_move(panel, delta); err != nil {
		set_status(app, fmt.aprintf(tr("Nie można otworzyć katalogu z historii: %s"), os.error_string(err)))
	} else if old_index != panel.history_index {
		set_status(app, fmt.aprintf(tr("Katalog: %s"), panel.path))
	}
}
