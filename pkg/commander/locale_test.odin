package commander

import "core:encoding/json"
import "core:testing"

@(test)
catalog_fallback_and_validation :: proc(t: ^testing.T) {
	catalog, ok := parse_catalog(`{"Gotowy":"Ready","Nazwa":""}`)
	defer json.destroy_value(catalog)
	testing.expect(t, ok)
	testing.expect_value(t, translate(catalog, "Gotowy"), "Ready")
	testing.expect_value(t, translate(catalog, "Nazwa"), "Nazwa")
	testing.expect_value(t, translate(catalog, "Rozmiar"), "Rozmiar")
	for data in ([]string{
		`[]`, `{"Gotowy":42}`, `{"Gotowy":"\u001b[31mReady"}`,
		`{"Katalog: %s":"Directory: %d"}`, `{"Gotowy":"Ready %s"}`,
		`{"Gotowy":"Ready","Gotowy":"Other"}`, `{`,
	}) {
		value, valid := parse_catalog(data)
		defer json.destroy_value(value)
		testing.expect(t, !valid)
	}
}

@(test)
bundled_languages_have_matching_entries :: proc(t: ^testing.T) {
	english, en_ok := parse_catalog(ENGLISH_CATALOG)
	defer json.destroy_value(english)
	polish, pl_ok := parse_catalog(#load("../../config/locales/pl.json", string))
	defer json.destroy_value(polish)
	testing.expect(t, en_ok && pl_ok)
	en := english.(json.Object)
	pl := polish.(json.Object)
	testing.expect_value(t, len(en), len(pl))
	for key in pl {
		entry, found := en[key]
		testing.expect(t, found)
		if found { testing.expect(t, len(string(entry.(json.String))) > 0) }
	}
	testing.expect_value(t, translate(english, "Gotowy"), "Ready")
	testing.expect_value(t, language_code("en_US.UTF-8"), "en")
	testing.expect_value(t, language_code("pl-PL"), "pl")
	testing.expect(t, !translation_is_safe("%s %d", "%d %s"))
	testing.expect(t, translation_is_safe("%s: %d%%", "%s: %d%%"))
}
