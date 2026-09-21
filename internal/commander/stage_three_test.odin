package commander

import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

@(test)
content_search_finds_text_and_skips_binary_files :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-content-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	text_file := filepath.join({root, "notes.txt"}) or_else ""
	binary_file := filepath.join({root, "binary.dat"}) or_else ""
	defer delete(text_file)
	defer delete(binary_file)
	testing.expect(t, os.write_entire_file_from_string(text_file, "Ala ma unikalnego kota") == nil)
	testing.expect(t, os.write_entire_file(binary_file, []byte{0, 'k', 'o', 't'}) == nil)

	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], root) == nil)
	app.search_query = strings.clone("UNIKALNEGO") or_else ""
	app.search_contents = true
	run_search(&app)
	testing.expect_value(t, len(app.search_results), 1)
	testing.expect_value(t, filepath.base(app.search_results[0]), "notes.txt")
}

@(test)
bookmarks_are_saved_and_loaded_from_config_file :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-bookmark-persist-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	store := filepath.join({root, "config", "bookmarks"}) or_else ""
	defer delete(store)

	first: App_State
	defer app_destroy(&first)
	testing.expect(t, panel_load(&first.panels[0], root) == nil)
	first.bookmarks_file = strings.clone(store) or_else ""
	testing.expect(t, add_current_bookmark(&first))

	second: App_State
	defer app_destroy(&second)
	bookmarks_load_file(&second, store)
	testing.expect_value(t, len(second.bookmarks), 1)
	testing.expect_value(t, second.bookmarks[0], first.panels[0].path)
}

@(test)
directory_size_sums_regular_files_recursively :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-size-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	nested := filepath.join({root, "nested"}) or_else ""
	one := filepath.join({root, "one"}) or_else ""
	two := filepath.join({nested, "two"}) or_else ""
	defer delete(nested)
	defer delete(one)
	defer delete(two)
	testing.expect(t, os.make_directory(nested) == nil)
	testing.expect(t, os.write_entire_file_from_string(one, "1234") == nil)
	testing.expect(t, os.write_entire_file_from_string(two, "123456") == nil)
	testing.expect_value(t, directory_size(root), i64(10))
}

@(test)
properties_include_owner_group_and_dates :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "twin-commander-property-extra-*", context.allocator)
	if !testing.expect(t, err == nil) do return
	defer delete(root)
	defer os.remove_all(root)
	file := filepath.join({root, "details.txt"}) or_else ""
	defer delete(file)
	testing.expect(t, os.write_entire_file_from_string(file, "details") == nil)
	app: App_State
	defer app_destroy(&app)
	testing.expect(t, panel_load(&app.panels[0], root) == nil)
	testing.expect(t, panel_select_name(&app.panels[0], "details.txt"))
	begin_properties(&app)
	testing.expect(t, len(app.property_owner) > 0)
	testing.expect(t, len(app.property_group) > 0)
	testing.expect(t, len(app.property_modified) > 1)
	testing.expect(t, len(app.property_accessed) > 1)
	testing.expect(t, len(app.property_created) > 1)
}
