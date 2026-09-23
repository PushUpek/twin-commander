package commander

import "core:time"
import "tc:pkg/tui"

handle_mouse_event :: proc(ctx: ^tui.Context, app: ^App_State, event: tui.Event, running: ^bool) {
	width, height := tui.size(ctx)
	if app.viewer_pending {
		if event.mouse_action == .Scroll_Up do app.viewer_top = max(app.viewer_top - 3, 0)
		if event.mouse_action == .Scroll_Down do viewer_move(app, 3)
		return
	}
	if app.help_pending {
		if event.mouse_action == .Scroll_Up do app.help_offset = max(app.help_offset - 3, 0)
		if event.mouse_action == .Scroll_Down do app.help_offset = min(app.help_offset + 3, help_max_offset(ctx))
		return
	}
	if app.menu_kind != .None {
		if event.mouse_action != .Press || event.mouse_button != 0 do return
		count := len(MAIN_MENU_ITEMS)
		if app.menu_kind == .User do count = len(USER_MENU_ITEMS)
		dialog_height := min(count + 4, height - 2)
		visible := max(dialog_height - 3, 1)
		top := (height - dialog_height) / 2
		row := event.mouse_y - top - 1
		if row < 0 || row >= visible do return
		offset := max(app.menu_selected - visible + 1, 0)
		selection := offset + row
		if selection >= count do return
		app.menu_selected = selection
		if mouse_is_double_click(app, -1, selection) {
			kind := app.menu_kind
			app.menu_kind = .None
			activate_menu_item(ctx, app, running, kind, selection)
		}
		return
	}
	if app.exit_pending || app.help_pending || app.remote_edit_pending || app.sync_pending ||
		app.command_edit_pending || app.checksum_pending || app.copy_edit_pending ||
		app.move_edit_pending || app.create_edit_pending || app.delete_pending ||
		app.overwrite_pending || app.move_pending {
		return
	}
	if event.mouse_y < 0 || event.mouse_y >= height - 2 do return
	panel_index := 0
	panel_x := 0
	panel_width := width / 2
	if event.mouse_x >= panel_width {
		panel_index = 1
		panel_x = panel_width
		panel_width = width - panel_width
	}
	if event.mouse_x <= panel_x || event.mouse_x >= panel_x + panel_width - 1 do return
	app.active_panel = panel_index
	panel := &app.panels[panel_index]
	if event.mouse_action == .Scroll_Up || event.mouse_action == .Scroll_Down {
		delta := -3 if event.mouse_action == .Scroll_Up else 3
		if panel.mode == .Tree do panel.tree_selected = clamp(panel.tree_selected + delta, 0, max(len(panel.tree_paths) - 1, 0))
		else do panel_move_selection(panel, delta)
		return
	}
	if event.mouse_action != .Press || event.mouse_button != 0 do return
	if panel.mode == .Tree {
		index := panel.tree_offset + event.mouse_y - 1
		if index < 0 || index >= len(panel.tree_paths) do return
		panel.tree_selected = index
		if mouse_is_double_click(app, panel_index, index) do panel_tree_activate(app)
		return
	}
	if panel.mode != .Files do return
	content_width := max(panel_width - 4, 0)
	show_metadata := content_width >= PANEL_ICON_WIDTH + PANEL_COLUMN_GAP + PANEL_MIN_NAME_WIDTH +
		PANEL_COLUMN_GAP + PANEL_SIZE_WIDTH + PANEL_COLUMN_GAP + PANEL_PERMISSIONS_WIDTH
	first_row := 2 if show_metadata else 1
	index := panel.offset + event.mouse_y - first_row
	if index < 0 || index >= panel_item_count(panel) do return
	panel.selected = index
	if mouse_is_double_click(app, panel_index, index) do activate_selected(ctx, app, running)
}

mouse_is_double_click :: proc(app: ^App_State, panel, item: int) -> bool {
	double := app.mouse_last_panel == panel && app.mouse_last_item == item &&
		time.tick_since(app.mouse_last_click) < 400 * time.Millisecond
	app.mouse_last_click = time.tick_now()
	app.mouse_last_panel = panel
	app.mouse_last_item = item
	return double
}
