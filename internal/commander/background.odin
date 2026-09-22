package commander

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"
import "tc:internal/fsops"
import "tc:internal/tui"

enqueue_copy_jobs :: proc(app: ^App_State) -> bool {
	entries, ok := copy_entries(app)
	defer delete(entries)
	if !ok do return false
	queued := 0
	for file in entries {
		destination, path_ok := copy_destination(app, file, "")
		if !path_ok {
			delete(destination)
			continue
		}
		if info, err := os.lstat(destination, context.temp_allocator); err == nil {
			os.file_info_delete(info, context.temp_allocator)
			delete(destination)
			continue
		}
		job := new(Background_Job)
		job.source = strings.clone(file.fullpath) or_else ""
		job.destination = destination
		job.name = strings.clone(file.name) or_else ""
		job.state = i32(Background_Job_State.Queued)
		append(&app.background_jobs, job)
		queued += 1
	}
	if queued == 0 {
		set_status(app, strings.clone(tr("Brak elementów do dodania do kolejki (cele mogą już istnieć)")) or_else "")
		return false
	}
	panel_clear_marks(&app.panels[app.active_panel])
	background_start_next(app)
	set_status(app, fmt.aprintf(tr("Dodano %d operacji do kolejki"), queued))
	return true
}

background_start_next :: proc(app: ^App_State) {
	for job in app.background_jobs {
		state := Background_Job_State(sync.atomic_load(&job.state))
		if state == .Running || state == .Paused do return
	}
	for job in app.background_jobs {
		if Background_Job_State(sync.atomic_load(&job.state)) != .Queued do continue
		sync.atomic_store(&job.state, i32(Background_Job_State.Running))
		job.worker = thread.create_and_start_with_data(rawptr(job), background_worker, name = "tc-copy")
		if job.worker == nil do sync.atomic_store(&job.state, i32(Background_Job_State.Failed))
		return
	}
}

background_worker :: proc(data: rawptr) {
	defer runtime.default_temp_allocator_destroy((^runtime.Default_Temp_Allocator)(context.temp_allocator.data))
	job := (^Background_Job)(data)
	err := fsops.Copy_Entry(job.source, job.destination, false, background_progress, data)
	if sync.atomic_load(&job.cancel_requested) != 0 {
		sync.atomic_store(&job.state, i32(Background_Job_State.Cancelled))
	} else if err != nil {
		sync.atomic_store(&job.state, i32(Background_Job_State.Failed))
	} else {
		sync.atomic_store(&job.percent, 100)
		sync.atomic_store(&job.state, i32(Background_Job_State.Done))
	}
}

background_progress :: proc(percent: int, data: rawptr) -> bool {
	job := (^Background_Job)(data)
	sync.atomic_store(&job.percent, i32(percent))
	for sync.atomic_load(&job.pause_requested) != 0 && sync.atomic_load(&job.cancel_requested) == 0 {
		sync.atomic_store(&job.state, i32(Background_Job_State.Paused))
		time.sleep(20 * time.Millisecond)
	}
	if sync.atomic_load(&job.cancel_requested) == 0 && Background_Job_State(sync.atomic_load(&job.state)) == .Paused {
		sync.atomic_store(&job.state, i32(Background_Job_State.Running))
	}
	return sync.atomic_load(&job.cancel_requested) == 0
}

background_tick :: proc(app: ^App_State) {
	finished := false
	for job in app.background_jobs {
		state := Background_Job_State(sync.atomic_load(&job.state))
		if job.worker != nil && (state == .Done || state == .Failed || state == .Cancelled) {
			thread.join(job.worker)
			thread.destroy(job.worker)
			job.worker = nil
			finished = true
		}
	}
	if finished {
		panel_refresh(&app.panels[0])
		panel_refresh(&app.panels[1])
	}
	background_start_next(app)
}

background_has_active_job :: proc(app: ^App_State) -> bool {
	for job in app.background_jobs {
		state := Background_Job_State(sync.atomic_load(&job.state))
		if state == .Queued || state == .Running || state == .Paused do return true
	}
	return false
}

background_destroy :: proc(app: ^App_State) {
	for job in app.background_jobs {
		if job == nil do continue
		if job.worker != nil {
			sync.atomic_store(&job.cancel_requested, 1)
			sync.atomic_store(&job.pause_requested, 0)
			thread.join(job.worker)
			thread.destroy(job.worker)
		}
		delete(job.source)
		delete(job.destination)
		delete(job.name)
		free(job)
	}
	delete(app.background_jobs)
}

begin_background_jobs :: proc(app: ^App_State) {
	app.background_pending = true
	app.background_selected = clamp(app.background_selected, 0, max(len(app.background_jobs) - 1, 0))
}

handle_background_event :: proc(app: ^App_State, event: tui.Event) {
	if event.kind == .Key {
		#partial switch event.key {
		case .Escape: app.background_pending = false
		case .Up: app.background_selected = max(app.background_selected - 1, 0)
		case .Down: app.background_selected = min(app.background_selected + 1, max(len(app.background_jobs) - 1, 0))
		case:
		}
		return
	}
	if event.kind != .Text || event.modifiers != {} || len(app.background_jobs) == 0 do return
	job := app.background_jobs[app.background_selected]
	switch event.text {
	case 'p', 'P':
		state := Background_Job_State(sync.atomic_load(&job.state))
		if state == .Running do sync.atomic_store(&job.pause_requested, 1)
	case 'r', 'R':
		sync.atomic_store(&job.pause_requested, 0)
	case 'c', 'C':
		state := Background_Job_State(sync.atomic_load(&job.state))
		if state == .Queued {
			sync.atomic_store(&job.state, i32(Background_Job_State.Cancelled))
		} else if state == .Running || state == .Paused {
			sync.atomic_store(&job.cancel_requested, 1)
			sync.atomic_store(&job.pause_requested, 0)
		}
	case:
	}
}

background_state_label :: proc(state: Background_Job_State) -> string {
	switch state {
	case .Queued: return tr("oczekuje")
	case .Running: return tr("działa")
	case .Paused: return tr("pauza")
	case .Done: return tr("gotowe")
	case .Failed: return tr("błąd")
	case .Cancelled: return tr("anulowane")
	}
	return ""
}

draw_background_dialog :: proc(buffer: ^tui.Buffer, width, height: int, app: ^App_State, theme: Theme) {
	dialog_height := min(18, height - 2)
	dialog := dialog_open(buffer, width, height, dialog_height, tr("Kolejka operacji"), theme)
	visible := max(dialog_height - 4, 1)
	offset := max(app.background_selected - visible + 1, 0)
	if len(app.background_jobs) == 0 do dialog_write(dialog, 2, tr("Kolejka jest pusta"))
	for row in 0 ..< min(visible, len(app.background_jobs) - offset) {
		index := offset + row
		job := app.background_jobs[index]
		state := Background_Job_State(sync.atomic_load(&job.state))
		label := fmt.aprintf("%3d%%  %-9s  %s", sync.atomic_load(&job.percent), background_state_label(state), job.name)
		defer delete(label)
		style := theme.dialog_surface
		if index == app.background_selected do style = theme.dialog_accent
		tui.buffer_write(buffer, dialog.rect.x + 3, dialog.rect.y + 1 + row, label, style, dialog.rect.width - 6)
	}
	dialog_write(dialog, dialog_height - 2, tr(" P Pauza   R Wznów   C Anuluj   Esc Zamknij "), .Action)
}
