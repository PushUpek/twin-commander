package commander_themes

import "core:testing"
import "tc:internal/tui"

@(test)
configured_kanso_themes_are_valid_toml :: proc(t: ^testing.T) {
	pearl, pearl_ok := light_kanso_pearl(context.allocator)
	defer theme_destroy(&pearl)
	testing.expect(t, pearl_ok)
	testing.expect_value(t, pearl.name, "Kanso Pearl")
	testing.expect_value(t, pearl.screen.background_rgb, tui.rgb(0xF2F1EF))

	mist, mist_ok := dark_kanso_mist(context.allocator)
	defer theme_destroy(&mist)
	testing.expect(t, mist_ok)
	testing.expect_value(t, mist.name, "Kanso Mist")
	testing.expect_value(t, mist.screen.background_rgb, tui.rgb(0x22262D))
}

@(test)
invalid_or_incomplete_theme_is_rejected :: proc(t: ^testing.T) {
	_, ok := parse_theme("name = \"Broken\"\n[screen]\nbackground = \"not-a-color\"\n")
	testing.expect(t, !ok)
}

@(test)
partial_skin_inherits_and_can_disable_attributes :: proc(t: ^testing.T) {
	base, loaded := dark_kanso_mist(context.allocator)
	defer theme_destroy(&base)
	testing.expect(t, loaded)
	skin, ok := parse_theme("name = \"Custom\"\n[panel_border_active]\nforeground = \"#FF8800\"\nbold = false\n", base)
	testing.expect(t, ok)
	testing.expect_value(t, skin.screen, base.screen)
	testing.expect_value(t, skin.panel_border_active.foreground_rgb, tui.rgb(0xFF8800))
	testing.expect(t, .Bold not_in skin.panel_border_active.attributes)
	testing.expect_value(t, skin.panel_border_active.background_rgb, base.panel_border_active.background_rgb)
	_, invalid := parse_theme("[screen]\nforeground = \"broken\"", base)
	testing.expect(t, !invalid)
}
