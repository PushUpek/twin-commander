package commander

import "core:os"
import "core:thread"
import "core:time"
import "tc:internal/fsops"
import "tc:internal/tui"

Mark_Mode :: enum {
	Select,
	Unselect,
}

Menu_Kind :: enum {
	None,
	User,
	Main,
}

File_Association :: struct {
	extension: string,
	command: string,
}

Background_Job_State :: enum i32 {
	Queued,
	Running,
	Paused,
	Done,
	Failed,
	Cancelled,
}

Checksum_Algorithm :: enum {
	SHA256,
	MD5,
	SHA1,
	SHA224,
	SHA384,
	SHA512,
}

Panel_Mode :: enum {
	Files,
	Tree,
	Info,
	Quick,
}

Shortcut_Action :: enum {
	Help,
	User_Menu,
	Main_Menu,
	View,
	Edit,
	Copy,
	Move,
	Create,
	Delete,
	Exit,
	Panel_Mode,
	Recursive_Compare,
	Sync,
	Remote,
	Checksum,
}

Shortcut_Binding :: struct {
	action: Shortcut_Action,
	kind: tui.Event_Kind,
	key: tui.Key,
	text: rune,
	modifiers: tui.Modifiers,
}

Background_Job :: struct {
	source: string,
	destination: string,
	name: string,
	percent: i32,
	state: i32,
	pause_requested: i32,
	cancel_requested: i32,
	worker: ^thread.Thread,
}

Panel_State :: struct {
	path:     string,
	remote:   bool,
	remote_return_path: string,
	mode: Panel_Mode,
	tree_paths: [dynamic]string,
	tree_selected: int,
	tree_offset: int,
	preview_path: string,
	preview_data: []byte,
	files:    []os.File_Info,
	marked:   [dynamic]string,
	selected: int,
	offset:   int,
	show_hidden: bool,
	sort_kind: fsops.Sort_Kind,
	sort_reverse: bool,
	filter: string,
	history: [dynamic]string,
	history_index: int,
	quick_search: string,
	free_bytes: i64,
	total_bytes: i64,
	space_known: bool,
	archive_root: string,
	archive_source: string,
	archive_parent: string,
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
	filter_edit_pending: bool,
	filter_text: string,
	filter_cursor: int,
	mark_edit_pending: bool,
	mark_mode: Mark_Mode,
	mark_pattern: string,
	mark_pattern_cursor: int,
	search_edit_pending: bool,
	search_results_pending: bool,
	search_query: string,
	search_query_cursor: int,
	search_contents: bool,
	search_root: string,
	search_results: [dynamic]string,
	search_selected: int,
	properties_pending: bool,
	property_path: string,
	property_name: string,
	property_kind: string,
	property_modified: string,
	property_accessed: string,
	property_created: string,
	property_size: i64,
	property_mode: string,
	property_mode_cursor: int,
	property_owner: string,
	property_group: string,
	property_is_symlink: bool,
	bookmarks_pending: bool,
	bookmarks: [dynamic]string,
	bookmark_selected: int,
	bookmarks_file: string,
	command_edit_pending: bool,
	command_text: string,
	command_cursor: int,
	help_pending: bool,
	help_offset: int,
	menu_kind: Menu_Kind,
	menu_selected: int,
	shortcuts: [dynamic]Shortcut_Binding,
	mouse_last_click: time.Tick,
	mouse_last_panel: int,
	mouse_last_item: int,
	remote_edit_pending: bool,
	remote_text: string,
	remote_cursor: int,
	sync_pending: bool,
	sync_new_count: int,
	sync_changed_count: int,
	sync_extra_count: int,
	viewer_pending: bool,
	viewer_search_edit_pending: bool,
	viewer_path: string,
	viewer_data: []byte,
	viewer_line_starts: [dynamic]int,
	viewer_formatted_data: []byte,
	viewer_formatted_line_starts: [dynamic]int,
	viewer_json_available: bool,
	viewer_formatted: bool,
	viewer_syntax: bool,
	viewer_top: int,
	viewer_hex: bool,
	viewer_query: string,
	viewer_query_cursor: int,
	link_edit_pending: bool,
	link_hard: bool,
	link_source: string,
	link_name: string,
	link_name_cursor: int,
	checksum_pending: bool,
	checksum_algorithm: Checksum_Algorithm,
	checksum_path: string,
	checksum_hash: string,
	checksum_other_path: string,
	checksum_other_hash: string,
	checksum_equal: bool,
	associations: [dynamic]File_Association,
	background_jobs: [dynamic]^Background_Job,
	background_pending: bool,
	background_selected: int,
	copying:           bool,
	copy_name:         string,
	copy_target_name:  string,
	copy_name_cursor:  int,
	move_name:         string,
	move_name_cursor:  int,
	pending_name:      string,
	pending_count:     int,
	copy_percent:      int,
	operation_label:   string,
}

app_destroy :: proc(app: ^App_State) {
	background_destroy(app)
	for index in 0 ..< len(app.panels) {
		panel_destroy(&app.panels[index])
	}
	destroy_theme(&app.theme)
	delete(app.status)
	delete(app.remote_text)
	delete(app.shortcuts)
	delete(app.copy_target_name)
	delete(app.move_name)
	delete(app.create_name)
	delete(app.filter_text)
	delete(app.mark_pattern)
	delete(app.search_query)
	delete(app.search_root)
	for path in app.search_results do delete(path)
	delete(app.search_results)
	delete(app.property_path)
	delete(app.property_name)
	delete(app.property_kind)
	delete(app.property_modified)
	delete(app.property_accessed)
	delete(app.property_created)
	delete(app.property_mode)
	delete(app.property_owner)
	delete(app.property_group)
	for path in app.bookmarks do delete(path)
	delete(app.bookmarks)
	delete(app.bookmarks_file)
	delete(app.command_text)
	delete(app.viewer_path)
	delete(app.viewer_data)
	delete(app.viewer_line_starts)
	delete(app.viewer_formatted_data)
	delete(app.viewer_formatted_line_starts)
	delete(app.viewer_query)
	delete(app.link_source)
	delete(app.link_name)
	delete(app.checksum_path)
	delete(app.checksum_hash)
	delete(app.checksum_other_path)
	delete(app.checksum_other_hash)
	for association in app.associations {
		delete(association.extension)
		delete(association.command)
	}
	delete(app.associations)
	delete(app.operation_label)
}

set_status :: proc(app: ^App_State, status: string) {
	delete(app.status)
	app.status = status
}
