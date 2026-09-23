package commander

import "core:encoding/json"
import "core:fmt"
import "core:os"

// The application has one locale, loaded once before entering the event loop.
locale_catalog: json.Value
ENGLISH_CATALOG :: #load("../../config/locales/en.json", string)

locale_init :: proc() {
	language := os.get_env("TWIN_COMMANDER_LANGUAGE", context.temp_allocator)
	if len(language) == 0 {
		for variable in ([]string{"LC_ALL", "LC_MESSAGES", "LANG"}) {
			language = os.get_env(variable, context.temp_allocator)
			if len(language) > 0 { break }
		}
	}
	if language_code(language) == "en" {
		locale_catalog, _ = json.parse(ENGLISH_CATALOG)
	}
	path := os.get_env("TWIN_COMMANDER_LOCALE_FILE", context.temp_allocator)
	if len(path) == 0 { return }
	data, err := os.read_entire_file(path, context.temp_allocator)
	if err != nil {
		fmt.eprintf("Cannot read locale file %s; using default language\n", path)
		return
	}
	defer delete(data, context.temp_allocator)
	catalog, ok := parse_catalog(string(data))
	if !ok {
		fmt.eprintf("Invalid locale file %s; using default language\n", path)
		return
	}
	locale_destroy()
	locale_catalog = catalog
}

locale_destroy :: proc() {
	json.destroy_value(locale_catalog)
	locale_catalog = {}
}

language_code :: proc(value: string) -> string {
	for i in 0 ..< len(value) {
		if value[i] == '_' || value[i] == '-' || value[i] == '.' || value[i] == '@' {
			return value[:i]
		}
	}
	return value
}

parse_catalog :: proc(data: string) -> (json.Value, bool) {
	value, err := json.parse(data)
	if err != nil { return {}, false }
	object, ok := value.(json.Object)
	if !ok {
		json.destroy_value(value)
		return {}, false
	}
	for source, entry in object {
		text, is_string := entry.(json.String)
		if !is_string || !translation_is_safe(source, string(text)) {
			json.destroy_value(value)
			return {}, false
		}
	}
	return value, true
}

tr :: proc(source: string) -> string {
	return translate(locale_catalog, source)
}

translate :: proc(catalog: json.Value, source: string) -> string {
	if object, ok := catalog.(json.Object); ok {
		if entry, found := object[source]; found {
			if text, is_string := entry.(json.String); is_string && len(text) > 0 {
				return string(text)
			}
		}
	}
	return source
}

// Keep printf arguments in the original order and reject terminal control codes.
translation_is_safe :: proc(source, text: string) -> bool {
	for character in text {
		if character < 32 || character == 127 || (character >= 128 && character < 160) { return false }
	}
	si, ti := 0, 0
	for {
		for si < len(source) && source[si] != '%' { si += 1 }
		for ti < len(text) && text[ti] != '%' { ti += 1 }
		if si == len(source) || ti == len(text) { return si == len(source) && ti == len(text) }
		if si + 1 >= len(source) || ti + 1 >= len(text) || source[si + 1] != text[ti + 1] { return false }
		si += 2
		ti += 2
	}
}
