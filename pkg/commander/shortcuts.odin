package commander

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:pkg/tui"

shortcut_action_name :: proc(action: Shortcut_Action) -> string {
	switch action {
	case .Help: return "help"
	case .User_Menu: return "user_menu"
	case .Main_Menu: return "main_menu"
	case .View: return "view"
	case .Edit: return "edit"
	case .Copy: return "copy"
	case .Move: return "move"
	case .Create: return "create"
	case .Delete: return "delete"
	case .Exit: return "exit"
	case .Panel_Mode: return "panel_mode"
	case .Recursive_Compare: return "recursive_compare"
	case .Sync: return "sync"
	case .Remote: return "remote"
	case .Checksum: return "checksum"
	}
	return ""
}

shortcut_default :: proc(action: Shortcut_Action) -> string {
	switch action {
	case .Help: return "F1"
	case .User_Menu: return "F2"
	case .Main_Menu: return "F9"
	case .View: return "F3"
	case .Edit: return "F4"
	case .Copy: return "F5"
	case .Move: return "F6"
	case .Create: return "F7"
	case .Delete: return "F8"
	case .Exit: return "F10"
	case .Panel_Mode: return "F11"
	case .Recursive_Compare: return "F12"
	case .Sync: return "Ctrl-Y"
	case .Remote: return "Ctrl-N"
	case .Checksum: return "Ctrl-K"
	}
	return ""
}

shortcut_parse :: proc(action: Shortcut_Action, description: string) -> (Shortcut_Binding, bool) {
	binding := Shortcut_Binding{action = action}
	remaining := strings.to_lower(strings.trim_space(description), context.temp_allocator) or_else ""
	for {
		if strings.has_prefix(remaining, "ctrl-") {
			binding.modifiers += {.Control}
			remaining = remaining[5:]
		} else if strings.has_prefix(remaining, "alt-") {
			binding.modifiers += {.Alt}
			remaining = remaining[4:]
		} else if strings.has_prefix(remaining, "shift-") {
			binding.modifiers += {.Shift}
			remaining = remaining[6:]
		} else {
			break
		}
	}
	binding.kind = .Key
	switch remaining {
	case "f1": binding.key = .F1
	case "f2": binding.key = .F2
	case "f3": binding.key = .F3
	case "f4": binding.key = .F4
	case "f5": binding.key = .F5
	case "f6": binding.key = .F6
	case "f7": binding.key = .F7
	case "f8": binding.key = .F8
	case "f9": binding.key = .F9
	case "f10": binding.key = .F10
	case "f11": binding.key = .F11
	case "f12": binding.key = .F12
	case "esc", "escape": binding.key = .Escape
	case "enter": binding.key = .Enter
	case "tab": binding.key = .Tab
	case:
		if strings.rune_count(remaining) != 1 do return {}, false
		if .Shift in binding.modifiers do return {}, false
		binding.kind = .Text
		for ch in remaining { binding.text = ch; break }
	}
	return binding, true
}

shortcut_load :: proc(app: ^App_State) {
	delete(app.shortcuts)
	app.shortcuts = nil
	for index in 0 ..< int(Shortcut_Action.Checksum) + 1 {
		action := Shortcut_Action(index)
		binding, ok := shortcut_parse(action, shortcut_default(action))
		if ok do append(&app.shortcuts, binding)
	}
	path := os.get_env("TWIN_COMMANDER_SHORTCUTS_FILE", context.temp_allocator)
	if len(path) == 0 {
		config_dir, err := os.user_config_dir(context.temp_allocator)
		if err == nil do path = filepath.join({config_dir, "twin-commander", "shortcuts.json"}, context.temp_allocator) or_else ""
	}
	if len(path) == 0 do return
	data, read_err := os.read_entire_file(path, context.temp_allocator)
	if read_err != nil do return
	parsed, parse_err := json.parse(data)
	if parse_err != nil {
		fmt.eprintln("Invalid shortcuts configuration: ", path)
		return
	}
	defer json.destroy_value(parsed)
	object, valid := parsed.(json.Object)
	if !valid do return
	bindings := make([dynamic]Shortcut_Binding, len(app.shortcuts))
	defer delete(bindings)
	copy(bindings[:], app.shortcuts[:])
	for name, value in object {
		found := false
		for &binding in bindings {
			if name != shortcut_action_name(binding.action) do continue
			text, is_string := value.(json.String)
			if !is_string do return
			parsed_binding, ok := shortcut_parse(binding.action, string(text))
			if !ok do return
			binding = parsed_binding
			found = true
			break
		}
		if !found do return
	}
	for binding, i in bindings {
		for other, j in bindings {
			if i >= j do continue
			if shortcut_same(binding, other) do return
		}
	}
	copy(app.shortcuts[:], bindings[:])
}

shortcut_same :: proc(left, right: Shortcut_Binding) -> bool {
	return left.kind == right.kind && left.key == right.key && left.text == right.text &&
		left.modifiers == right.modifiers
}

shortcut_matches :: proc(binding: Shortcut_Binding, event: tui.Event) -> bool {
	if binding.kind != event.kind || binding.modifiers != event.modifiers do return false
	if event.kind == .Key do return binding.key == event.key
	if event.kind == .Text do return binding.text == event.text
	return false
}

handle_shortcut :: proc(ctx: ^tui.Context, app: ^App_State, event: tui.Event, running: ^bool) -> bool {
	bindings := app.shortcuts[:]
	if len(bindings) == 0 {
		bindings = []Shortcut_Binding{
			{action = .Help, kind = .Key, key = .F1},
			{action = .User_Menu, kind = .Key, key = .F2},
			{action = .Main_Menu, kind = .Key, key = .F9},
			{action = .View, kind = .Key, key = .F3},
			{action = .Edit, kind = .Key, key = .F4},
			{action = .Copy, kind = .Key, key = .F5},
			{action = .Move, kind = .Key, key = .F6},
			{action = .Create, kind = .Key, key = .F7},
			{action = .Delete, kind = .Key, key = .F8},
			{action = .Exit, kind = .Key, key = .F10},
			{action = .Panel_Mode, kind = .Key, key = .F11},
			{action = .Recursive_Compare, kind = .Key, key = .F12},
			{action = .Sync, kind = .Text, text = 'y', modifiers = {.Control}},
			{action = .Remote, kind = .Text, text = 'n', modifiers = {.Control}},
			{action = .Checksum, kind = .Text, text = 'k', modifiers = {.Control}},
		}
	}
	for binding in bindings {
		if !shortcut_matches(binding, event) do continue
		if app.panels[app.active_panel].mode != .Files && shortcut_requires_files(binding.action) {
			set_status(app, strings.clone(tr("Przełącz panel na widok plików, aby wykonać tę operację")) or_else "")
			return true
		}
		switch binding.action {
		case .Help: app.help_pending = true
		case .User_Menu: begin_menu(app, .User)
		case .Main_Menu: begin_menu(app, .Main)
		case .View: begin_viewer(app)
		case .Edit:
			if panel_is_archive(&app.panels[app.active_panel]) do archive_read_only_status(app)
			else do open_selected_file(ctx, app, .Edit, running)
		case .Copy: copy_selected_file(ctx, app)
		case .Move:
			if panel_is_archive(&app.panels[app.active_panel]) do archive_read_only_status(app)
			else do move_selected_entry(app, ctx)
		case .Create:
			if panel_is_archive(&app.panels[app.active_panel]) do archive_read_only_status(app)
			else do begin_create_entry(app)
		case .Delete:
			if panel_is_archive(&app.panels[app.active_panel]) do archive_read_only_status(app)
			else do delete_selected_entry(app)
		case .Exit: app.exit_pending = true
		case .Panel_Mode: panel_mode_cycle(app)
		case .Recursive_Compare: compare_recursive(app)
		case .Sync: begin_sync(app)
		case .Remote: begin_remote(app)
		case .Checksum: begin_checksum(app)
		}
		return true
	}
	return false
}

shortcut_requires_files :: proc(action: Shortcut_Action) -> bool {
	#partial switch action {
	case .View, .Edit, .Copy, .Move, .Create, .Delete, .Checksum:
		return true
	case:
		return false
	}
}
