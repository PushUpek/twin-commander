package commander

import "core:os"

Panel_State :: struct {
	path:     string,
	files:    []os.File_Info,
	marked:   [dynamic]string,
	selected: int,
	offset:   int,
}

App_State :: struct {
	panels:            [2]Panel_State,
	active_panel:      int,
	theme_mode:        Theme_Mode,
	theme:             Theme,
	theme_overridden:  bool,
	status:            string,
	exit_pending:      bool,
	overwrite_pending: bool,
	copy_edit_pending: bool,
	create_edit_pending: bool,
	create_name: string,
	create_name_cursor: int,
	move_edit_pending: bool,
	move_pending:      bool,
	delete_pending:    bool,
	copying:           bool,
	copy_name:         string,
	copy_target_name:  string,
	copy_name_cursor:  int,
	move_name:         string,
	move_name_cursor:  int,
	pending_name:      string,
	pending_count:     int,
	copy_percent:      int,
}

app_destroy :: proc(app: ^App_State) {
	for index in 0 ..< len(app.panels) {
		panel_destroy(&app.panels[index])
	}
	destroy_theme(&app.theme)
	delete(app.status)
	delete(app.copy_target_name)
	delete(app.move_name)
	delete(app.create_name)
}

set_status :: proc(app: ^App_State, status: string) {
	delete(app.status)
	app.status = status
}
