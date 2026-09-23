package commander

import "core:crypto/legacy/md5"
import "core:crypto/legacy/sha1"
import "core:crypto/sha2"
import "core:encoding/hex"
import "core:fmt"
import "core:io"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "tc:pkg/tui"

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
	hash, ok := checksum_file(file.fullpath, app.checksum_algorithm)
	if !ok {
		set_status(app, fmt.aprintf(tr("Nie można obliczyć sumy %s"), checksum_name(app.checksum_algorithm)))
		return
	}
	clear_checksum(app)
	app.checksum_path = strings.clone(file.fullpath) or_else ""
	app.checksum_hash = hash
	other := &app.panels[1 - app.active_panel]
	for candidate in other.files {
		if candidate.name == file.name && candidate.type == .Regular {
			other_hash, other_ok := checksum_file(candidate.fullpath, app.checksum_algorithm)
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

checksum_name :: proc(algorithm: Checksum_Algorithm) -> string {
	switch algorithm {
	case .MD5: return "MD5"
	case .SHA1: return "SHA-1"
	case .SHA224: return "SHA-224"
	case .SHA384: return "SHA-384"
	case .SHA512: return "SHA-512"
	case .SHA256: return "SHA-256"
	}
	return "SHA-256"
}

checksum_extension :: proc(algorithm: Checksum_Algorithm) -> string {
	switch algorithm {
	case .MD5: return "md5"
	case .SHA1: return "sha1"
	case .SHA224: return "sha224"
	case .SHA384: return "sha384"
	case .SHA512: return "sha512"
	case .SHA256: return "sha256"
	}
	return "sha256"
}

sha256_file :: proc(path: string) -> (string, bool) {
	return checksum_file(path, .SHA256)
}

checksum_file :: proc(path: string, algorithm: Checksum_Algorithm) -> (string, bool) {
	if remote_path_valid(path) {
		temporary, temp_err := os.make_directory_temp("", "twin-commander-hash-*", context.allocator)
		if temp_err != nil do return "", false
		defer delete(temporary)
		defer os.remove_all(temporary)
		local := filepath.join({temporary, "file"}) or_else ""
		defer delete(local)
		if !remote_transfer(path, local, false) do return "", false
		return checksum_file(local, algorithm)
	}
	file, err := os.open(path)
	if err != nil do return "", false
	defer os.close(file)
	md5_ctx: md5.Context
	sha1_ctx: sha1.Context
	sha256_ctx: sha2.Context_256
	sha512_ctx: sha2.Context_512
	switch algorithm {
	case .MD5: md5.init(&md5_ctx)
	case .SHA1: sha1.init(&sha1_ctx)
	case .SHA224: sha2.init_224(&sha256_ctx)
	case .SHA384: sha2.init_384(&sha512_ctx)
	case .SHA512: sha2.init_512(&sha512_ctx)
	case .SHA256: sha2.init_256(&sha256_ctx)
	}
	buffer: [64 * 1024]byte
	for {
		count, read_err := os.read(file, buffer[:])
		if count > 0 {
			switch algorithm {
			case .MD5: md5.update(&md5_ctx, buffer[:count])
			case .SHA1: sha1.update(&sha1_ctx, buffer[:count])
			case .SHA224, .SHA256: sha2.update(&sha256_ctx, buffer[:count])
			case .SHA384, .SHA512: sha2.update(&sha512_ctx, buffer[:count])
			}
		}
		if read_err != nil {
			if read_err == os.Error(io.Error.EOF) do break
			return "", false
		}
		if count == 0 do break
	}
	digest: [sha2.DIGEST_SIZE_512]byte
	digest_size := sha2.DIGEST_SIZE_256
	switch algorithm {
	case .MD5:
		digest_size = md5.DIGEST_SIZE
		md5.final(&md5_ctx, digest[:digest_size])
	case .SHA1:
		digest_size = sha1.DIGEST_SIZE
		sha1.final(&sha1_ctx, digest[:digest_size])
	case .SHA224:
		digest_size = sha2.DIGEST_SIZE_224
		sha2.final(&sha256_ctx, digest[:digest_size])
	case .SHA384:
		digest_size = sha2.DIGEST_SIZE_384
		sha2.final(&sha512_ctx, digest[:digest_size])
	case .SHA512:
		digest_size = sha2.DIGEST_SIZE_512
		sha2.final(&sha512_ctx, digest[:digest_size])
	case .SHA256:
		sha2.final(&sha256_ctx, digest[:digest_size])
	}
	encoded := hex.encode(digest[:digest_size]) or_else nil
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
	if event.kind == .Key && event.key == .Tab {
		app.checksum_algorithm = Checksum_Algorithm((int(app.checksum_algorithm) + 1) % 6)
		new_hash, ok := checksum_file(app.checksum_path, app.checksum_algorithm)
		if !ok {
			set_status(app, fmt.aprintf(tr("Nie można obliczyć sumy %s"), checksum_name(app.checksum_algorithm)))
			return
		}
		delete(app.checksum_hash)
		app.checksum_hash = new_hash
		if len(app.checksum_other_path) > 0 {
			other_hash, other_ok := checksum_file(app.checksum_other_path, app.checksum_algorithm)
			delete(app.checksum_other_hash)
			app.checksum_other_hash = other_hash
			app.checksum_equal = other_ok && new_hash == other_hash
		}
	}
}

write_checksum_file :: proc(app: ^App_State) -> bool {
	output := fmt.aprintf("%s.%s", app.checksum_path, checksum_extension(app.checksum_algorithm))
	defer delete(output)
	contents := fmt.aprintf("%s  %s\n", app.checksum_hash, remote_basename(app.checksum_path))
	defer delete(contents)
	if remote_path_valid(output) {
		temporary, err := os.make_directory_temp("", "twin-commander-hash-save-*", context.allocator)
		if err != nil do return false
		defer delete(temporary)
		defer os.remove_all(temporary)
		local := filepath.join({temporary, "checksum"}) or_else ""
		defer delete(local)
		if os.write_entire_file_from_string(local, contents) != nil || !remote_transfer(local, output, false) {
			set_status(app, strings.clone(tr("Nie można zapisać zdalnej sumy kontrolnej")) or_else "")
			return false
		}
		panel_refresh(&app.panels[app.active_panel])
		set_status(app, fmt.aprintf(tr("Zapisano sumę: %s"), output))
		return true
	}
	if err := os.write_entire_file_from_string(output, contents); err != nil {
		set_status(app, fmt.aprintf(tr("Nie można zapisać sumy: %s"), os.error_string(err)))
		return false
	}
	panel_refresh(&app.panels[app.active_panel])
	set_status(app, fmt.aprintf(tr("Zapisano sumę: %s"), output))
	return true
}

draw_checksum_dialog :: proc(buffer: ^tui.Buffer, width, height: int, app: ^App_State, theme: Theme) {
	title := fmt.aprintf(tr("Suma kontrolna %s"), checksum_name(app.checksum_algorithm))
	defer delete(title)
	dialog := dialog_open(buffer, width, height, 16, title, theme, 74)
	chunk_size := 32
	if dialog.rect.width - 6 >= 64 do chunk_size = 64
	dialog_write(dialog, 1, remote_basename(app.checksum_path), .Accent)
	hash_rows := draw_checksum_hash(dialog, 2, app.checksum_hash, chunk_size)
	other_row := 3 + hash_rows
	if len(app.checksum_other_hash) > 0 {
		dialog_write(dialog, other_row, remote_basename(app.checksum_other_path), .Accent)
		other_rows := draw_checksum_hash(dialog, other_row + 1, app.checksum_other_hash, chunk_size)
		result := tr("RÓŻNE")
		if app.checksum_equal do result = tr("ZGODNE")
		comparison := fmt.aprintf(tr("Porównanie paneli: %s"), result)
		defer delete(comparison)
		dialog_write(dialog, other_row + other_rows + 2, comparison, .Accent)
	} else {
		dialog_write(dialog, other_row, tr("Brak pliku o tej samej nazwie w drugim panelu"))
	}
	footer := fmt.aprintf(tr(" Tab Algorytm   G Zapisz .%s   Enter/Esc Zamknij "), checksum_extension(app.checksum_algorithm))
	defer delete(footer)
	dialog_write(dialog, 14, footer, .Action)
}

draw_checksum_hash :: proc(dialog: Dialog_Template, row: int, hash: string, chunk_size: int) -> int {
	rows := max((len(hash) + chunk_size - 1) / chunk_size, 1)
	for index in 0 ..< rows {
		start := index * chunk_size
		end := min(start + chunk_size, len(hash))
		if rows == 1 {
			dialog_write(dialog, row + index, hash[start:end])
		} else {
			part := fmt.aprintf("%d/%d  %s", index + 1, rows, hash[start:end])
			dialog_write(dialog, row + index, part)
			delete(part)
		}
	}
	return rows
}
