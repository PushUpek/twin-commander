package commander

import "core:crypto/sha2"
import "core:encoding/hex"
import "core:fmt"
import "core:io"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:internal/tui"

begin_checksum :: proc(app: ^App_State) {
	panel := &app.panels[app.active_panel]
	if panel.selected <= 0 || panel.selected > len(panel.files) {
		set_status(app, strings.clone(tr("Wybierz plik")) or_else "")
		return
	}
	file := panel.files[panel.selected - 1]
	if file.type != .Regular {
		set_status(app, strings.clone(tr("Sumę można obliczyć tylko dla zwykłego pliku")) or_else "")
		return
	}
	hash, ok := sha256_file(file.fullpath)
	if !ok {
		set_status(app, strings.clone(tr("Nie można obliczyć sumy SHA-256")) or_else "")
		return
	}
	clear_checksum(app)
	app.checksum_path = strings.clone(file.fullpath) or_else ""
	app.checksum_hash = hash
	other := &app.panels[1 - app.active_panel]
	for candidate in other.files {
		if candidate.name == file.name && candidate.type == .Regular {
			other_hash, other_ok := sha256_file(candidate.fullpath)
			if other_ok {
				app.checksum_other_path = strings.clone(candidate.fullpath) or_else ""
				app.checksum_other_hash = other_hash
				app.checksum_equal = app.checksum_hash == app.checksum_other_hash
			}
			break
		}
	}
	app.checksum_pending = true
}

clear_checksum :: proc(app: ^App_State) {
	delete(app.checksum_path)
	delete(app.checksum_hash)
	delete(app.checksum_other_path)
	delete(app.checksum_other_hash)
	app.checksum_path = ""
	app.checksum_hash = ""
	app.checksum_other_path = ""
	app.checksum_other_hash = ""
	app.checksum_equal = false
	app.checksum_pending = false
}

sha256_file :: proc(path: string) -> (string, bool) {
	file, err := os.open(path)
	if err != nil do return "", false
	defer os.close(file)
	ctx: sha2.Context_256
	digest: [sha2.DIGEST_SIZE_256]byte
	sha2.init_256(&ctx)
	buffer: [64 * 1024]byte
	for {
		count, read_err := os.read(file, buffer[:])
		if count > 0 do sha2.update(&ctx, buffer[:count])
		if read_err != nil {
			if read_err == os.Error(io.Error.EOF) do break
			return "", false
		}
		if count == 0 do break
	}
	sha2.final(&ctx, digest[:])
	encoded := hex.encode(digest[:]) or_else nil
	if encoded == nil do return "", false
	return string(encoded), true
}

handle_checksum_event :: proc(app: ^App_State, event: tui.Event) {
	if event.kind == .Key && (event.key == .Escape || event.key == .Enter) {
		app.checksum_pending = false
		return
	}
	if event.kind == .Text && event.modifiers == {} && (event.text == 'g' || event.text == 'G') {
		write_checksum_file(app)
	}
}

write_checksum_file :: proc(app: ^App_State) -> bool {
	output := fmt.aprintf("%s.sha256", app.checksum_path)
	defer delete(output)
	contents := fmt.aprintf("%s  %s\n", app.checksum_hash, filepath.base(app.checksum_path))
	defer delete(contents)
	if err := os.write_entire_file_from_string(output, contents); err != nil {
		set_status(app, fmt.aprintf(tr("Nie można zapisać sumy: %s"), os.error_string(err)))
		return false
	}
	panel_refresh(&app.panels[app.active_panel])
	set_status(app, fmt.aprintf(tr("Zapisano sumę: %s"), output))
	return true
}

draw_checksum_dialog :: proc(buffer: ^tui.Buffer, width, height: int, app: ^App_State, theme: Theme) {
	dialog := dialog_open(buffer, width, height, 16, tr("Suma kontrolna SHA-256"), theme, 74)
	hash_fits := dialog.rect.width - 6 >= 64
	dialog_write(dialog, 1, filepath.base(app.checksum_path), .Accent)
	draw_checksum_hash(dialog, 2, app.checksum_hash, hash_fits)
	if len(app.checksum_other_hash) > 0 {
		dialog_write(dialog, 5, filepath.base(app.checksum_other_path), .Accent)
		draw_checksum_hash(dialog, 6, app.checksum_other_hash, hash_fits)
		result := tr("RÓŻNE")
		if app.checksum_equal do result = tr("ZGODNE")
		comparison := fmt.aprintf(tr("Porównanie paneli: %s"), result)
		defer delete(comparison)
		dialog_write(dialog, 9, comparison, .Accent)
	} else {
		dialog_write(dialog, 5, tr("Brak pliku o tej samej nazwie w drugim panelu"))
	}
	dialog_write(dialog, 14, tr(" G Zapisz .sha256   Enter/Esc Zamknij "), .Action)
}

draw_checksum_hash :: proc(dialog: Dialog_Template, row: int, hash: string, fits: bool) {
	if fits || len(hash) <= 32 {
		dialog_write(dialog, row, hash)
		return
	}
	first := fmt.aprintf("1/2  %s", hash[:32])
	second := fmt.aprintf("2/2  %s", hash[32:])
	defer delete(first)
	defer delete(second)
	dialog_write(dialog, row, first)
	dialog_write(dialog, row + 1, second)
}
