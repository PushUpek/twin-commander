package commander

import "core:os"

Panel_State :: struct {
	path:     string,
	files:    []os.File_Info,
	selected: int,
	offset:   int,
}

App_State :: struct {
	panels:       [2]Panel_State,
	active_panel: int,
	status:       string,
	copying:      bool,
	copy_name:    string,
	copy_percent: int,
}

app_destroy :: proc(app: ^App_State) {
	for index in 0 ..< len(app.panels) {
		panel_destroy(&app.panels[index])
	}
	delete(app.status)
}

set_status :: proc(app: ^App_State, status: string) {
	delete(app.status)
	app.status = status
}
