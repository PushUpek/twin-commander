package commander

import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"
import "core:time"
import "core:sync"
import "tc:internal/tui"

@(test)
footer_restores_function_key_prefixes_when_space_allows :: proc(t: ^testing.T) {
	testing.expect(t, strings.has_prefix(footer_labels(200), "[F1]"))
	testing.expect(t, strings.has_prefix(footer_labels(90), "[F1]"))
	testing.expect(t, strings.contains(footer_labels(80), "[F2]"))
	testing.expect(t, strings.contains(footer_labels(80), "[F9]"))
	testing.expect(t, strings.contains(footer_labels(80), "Menu użytkownika"))
	testing.expect(t, strings.contains(footer_labels(80), "Menu główne"))
	testing.expect(t, strings.rune_count(footer_labels(80)) <= 80)
}

@(test)
built_in_viewer_indexes_searches_and_switches_hex :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-viewer-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	path := filepath.join({root, "view.txt"}) or_else ""
	defer delete(path)
	testing.expect(t, os.write_entire_file_from_string(path, "first\nNeedle here\nthird") == nil)
	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], root) == nil)
	testing.expect(t, panel_select_name(&app.panels[0], "view.txt"))
	begin_viewer(&app)
	testing.expect(t, app.viewer_pending)
	testing.expect_value(t, len(app.viewer_line_starts), 3)
	app.viewer_query = strings.clone("needle") or_else ""
	testing.expect(t, viewer_find_next(&app))
	testing.expect_value(t, app.viewer_top, 1)
	testing.expect_value(t, find_bytes_fold(app.viewer_data, transmute([]byte)(string("THIRD")), 0), 18)
}

@(test)
symbolic_and_hard_links_are_created_in_other_panel :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-links-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	source_dir := filepath.join({root, "source"}) or_else ""
	destination_dir := filepath.join({root, "destination"}) or_else ""
	source := filepath.join({source_dir, "item.txt"}) or_else ""
	defer delete(source_dir); defer delete(destination_dir); defer delete(source)
	testing.expect(t, os.make_directory(source_dir) == nil)
	testing.expect(t, os.make_directory(destination_dir) == nil)
	testing.expect(t, os.write_entire_file_from_string(source, "linked") == nil)
	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], source_dir) == nil)
	testing.expect(t, panel_load(&app.panels[1], destination_dir) == nil)
	testing.expect(t, panel_select_name(&app.panels[0], "item.txt"))
	begin_link(&app)
	replace_edit_name(&app.link_name, "symbolic.txt")
	testing.expect(t, create_link(&app))
	symbolic := filepath.join({destination_dir, "symbolic.txt"}) or_else ""
	defer delete(symbolic)
	info, stat_err := os.lstat(symbolic, context.allocator)
	testing.expect(t, stat_err == nil && info.type == .Symlink)
	if stat_err == nil do os.file_info_delete(info, context.allocator)
	begin_link(&app, true)
	replace_edit_name(&app.link_name, "hard.txt")
	testing.expect(t, create_link(&app))
	hard := filepath.join({destination_dir, "hard.txt"}) or_else ""
	defer delete(hard)
	hard_data, read_err := os.read_entire_file(hard, context.temp_allocator)
	testing.expect(t, read_err == nil && string(hard_data) == "linked")
}

@(test)
sha256_compares_same_named_files_between_panels :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-checksum-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	left := filepath.join({root, "left"}) or_else ""
	right := filepath.join({root, "right"}) or_else ""
	defer delete(left); defer delete(right)
	testing.expect(t, os.make_directory(left) == nil)
	testing.expect(t, os.make_directory(right) == nil)
	for directory in ([]string{left, right}) {
		path := filepath.join({directory, "same.txt"}) or_else ""
		testing.expect(t, os.write_entire_file_from_string(path, "same") == nil)
		delete(path)
	}
	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], left) == nil)
	testing.expect(t, panel_load(&app.panels[1], right) == nil)
	testing.expect(t, panel_select_name(&app.panels[0], "same.txt"))
	begin_checksum(&app)
	testing.expect(t, app.checksum_pending && app.checksum_equal)
	testing.expect_value(t, len(app.checksum_hash), 64)
	testing.expect(t, write_checksum_file(&app))
}

@(test)
sha256_dialog_keeps_hash_on_one_line_when_it_fits :: proc(t: ^testing.T) {
	hash := "0123456789abcdef0123456789abcdefabcdef0123456789abcdef0123456789"
	app := App_State{checksum_path = "test.txt", checksum_hash = hash}
	theme := theme_for(.Dark)
	defer destroy_theme(&theme)
	buffer: tui.Buffer
	tui.buffer_init(&buffer, 80, 24)
	defer tui.buffer_destroy(&buffer)
	draw_checksum_dialog(&buffer, 80, 24, &app, theme)
	testing.expect_value(t, tui.buffer_get(&buffer, 6, 6).character, rune('0'))
	testing.expect_value(t, tui.buffer_get(&buffer, 69, 6).character, rune('9'))
	testing.expect_value(t, tui.buffer_get(&buffer, 6, 7).character, rune(' '))

	tui.buffer_init(&buffer, 60, 24)
	draw_checksum_dialog(&buffer, 60, 24, &app, theme)
	testing.expect_value(t, tui.buffer_get(&buffer, 5, 6).character, rune('1'))
	testing.expect_value(t, tui.buffer_get(&buffer, 5, 7).character, rune('2'))
	testing.expect_value(t, tui.buffer_get(&buffer, 10, 6).character, rune('0'))
	testing.expect_value(t, tui.buffer_get(&buffer, 10, 7).character, rune('a'))
}

@(test)
file_associations_are_case_insensitive_and_replaceable :: proc(t: ^testing.T) {
	app: App_State
	defer app_destroy(&app)
	association_set(&app, ".PDF", "first")
	testing.expect_value(t, association_for(&app, "/tmp/report.pdf"), "first")
	association_set(&app, ".pdf", "second --wait")
	testing.expect_value(t, association_for(&app, "/tmp/REPORT.PDF"), "second --wait")
}

@(test)
background_copy_queue_completes_and_refreshes_destination :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-background-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	left := filepath.join({root, "left"}) or_else ""
	right := filepath.join({root, "right"}) or_else ""
	source := filepath.join({left, "queued.txt"}) or_else ""
	defer delete(left); defer delete(right); defer delete(source)
	testing.expect(t, os.make_directory(left) == nil)
	testing.expect(t, os.make_directory(right) == nil)
	testing.expect(t, os.write_entire_file_from_string(source, "background") == nil)
	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], left) == nil)
	testing.expect(t, panel_load(&app.panels[1], right) == nil)
	testing.expect(t, panel_select_name(&app.panels[0], "queued.txt"))
	testing.expect(t, enqueue_copy_jobs(&app))
	for _ in 0 ..< 200 {
		background_tick(&app)
		if Background_Job_State(sync.atomic_load(&app.background_jobs[0].state)) == .Done do break
		time.sleep(time.Millisecond)
	}
	background_tick(&app)
	testing.expect(t, Background_Job_State(sync.atomic_load(&app.background_jobs[0].state)) == .Done)
	destination := filepath.join({right, "queued.txt"}) or_else ""
	defer delete(destination)
	data, read_err := os.read_entire_file(destination, context.temp_allocator)
	testing.expect(t, read_err == nil && string(data) == "background")
}

@(test)
tar_archive_opens_as_read_only_directory_and_returns_to_parent :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-archive-test-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	source_dir := filepath.join({root, "payload"}) or_else ""
	file := filepath.join({source_dir, "inside.txt"}) or_else ""
	archive := filepath.join({root, "sample.tar"}) or_else ""
	defer delete(source_dir); defer delete(file); defer delete(archive)
	testing.expect(t, os.make_directory(source_dir) == nil)
	testing.expect(t, os.write_entire_file_from_string(file, "archive") == nil)
	testing.expect(t, run_archive_process([]string{"tar", "-cf", archive, "-C", source_dir, "inside.txt"}, nil))
	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], root) == nil)
	testing.expect(t, open_archive(&app, archive))
	testing.expect(t, panel_is_archive(&app.panels[0]))
	testing.expect_value(t, app.panels[0].archive_source, archive)
	testing.expect(t, strings.has_suffix(app.status, "sample.tar"))
	testing.expect(t, panel_select_name(&app.panels[0], "inside.txt"))
	navigate_parent(&app)
	expected, abs_err := filepath.abs(root, context.allocator)
	defer delete(expected)
	testing.expect(t, abs_err == nil)
	testing.expect_value(t, app.panels[0].path, expected)
	testing.expect(t, !panel_is_archive(&app.panels[0]))
}
