# Twin Commander

Twin Commander is a modern two-panel file manager inspired by Norton Commander and written in [Odin](https://odin-lang.org/).

## Building

The Odin compiler must be available in `PATH`.

```sh
make
```

The executable is built in `build/`.

## Packages and releases

The `Build packages` workflow runs tests on macOS ARM, macOS Intel, and Linux x86-64. A `vX.Y.Z` tag publishes these files in GitHub Releases:

- `twin-commander-macos-arm64.tar.gz` for Apple Silicon,
- `twin-commander-macos-universal.tar.gz` for Apple Silicon and Intel,
- `.AppImage`, `.deb`, and `.rpm` packages for Linux x86-64,
- `SHA256SUMS` for verifying downloaded files.

The macOS archives contain `bin/twin-commander` and `share/twin-commander/themes`. After extracting an archive, run `bin/twin-commander` from an interactive terminal. The macOS binaries are not yet signed or notarized.

Homebrew can build the current version from `main`:

```sh
brew tap pushupek/twin-commander https://github.com/PushUpek/twin-commander.git
brew install --HEAD pushupek/twin-commander/twin-commander
```

The formula uses Homebrew's `odin` compiler. There is not yet a versioned formula or a separate tap repository with automatic updates.

On Debian or Ubuntu, install the downloaded `.deb` with `sudo apt install ./file.deb`. On RPM-based systems, install the downloaded `.rpm` with `sudo dnf install ./file.rpm`. These files do not create signed APT or DNF repositories, so they do not provide automatic updates. The AppImage is an executable file that can be launched from a terminal; desktop integration requires an environment that supports AppImage.

Windows releases (`.exe`, `.zip`, and an installer) require a Windows port of the terminal layer and the POSIX operations used by the application. The current code does not build natively on Windows, so the workflow does not publish a nonfunctional Windows file. After the port, a portable `.zip` and an Inno Setup installer would be a practical pair; the `.exe` can be included in both.

## Running

```sh
make run
```

## Configuration locations

On macOS and other Unix systems, Twin Commander prefers an existing `~/.config/twin-commander/` directory. Create it to keep user configuration in one place:

```sh
mkdir -p ~/.config/twin-commander/themes
```

The directory contains `bookmarks`, `associations`, and `shortcuts.json`. Default theme overrides go in `themes/dark_kanso_mist.toml` and `themes/light_kanso_pearl.toml`. Either theme file may contain only the fields that differ from the bundled theme. A missing theme file falls back to the bundled version.

If `~/.config/twin-commander/` does not exist, configuration files use the previous location returned by Odin's `os.user_config_dir`: `~/Library/Application Support/twin-commander/` on macOS, or the XDG configuration directory on Linux. Themes then use the previous project or installed-file lookup. Existing files are not moved automatically. Explicit `TWIN_COMMANDER_*_FILE` and theme-path environment variables still take precedence.

For a future native Windows port, the configuration root is the user's local AppData directory under `twin-commander/`. The current application still requires POSIX and does not run natively on Windows.

Each panel shows the contents of its own directory. The first column uses portable Unicode icons for directories and common file categories, including code, text, images, archives, media, and data. A Nerd Font is not required.

Keyboard shortcuts:

- `↑`/`↓` — move the selection.
- `Home`/`End`, `Page Up`/`Page Down` — jump to the beginning or end, or scroll by page.
- `Enter` — enter a directory, open a ZIP or TAR archive as a directory, or launch the associated program for a file. The `..` entry moves to the parent directory.
- `Backspace` — go to the parent directory.
- `←`/`→` — go to the previous or next directory in the active panel's history.
- `Tab` — switch the active panel.
- `Space` — mark or unmark an item and move to the next row.
- Type letters — find a name by prefix; `Backspace` or `Esc` clears the search.
- `+` / `\\` / `*` — mark items matching a mask, unmark them, or invert the marks.
- `/` or `Ctrl-F` — filter the active panel by part of a name; an empty filter shows everything.
- `Ctrl-D` — show or hide dotfiles.
- `Ctrl-S` — cycle through sorting by name, extension, size, and modification date; the next cycle reverses the order.
- `Ctrl-R` — refresh the panel while preserving the cursor and existing marks.
- `Alt-F7` or `Ctrl-G` — search recursively from the active panel's directory. In the dialog, `Tab` switches between filename and file-content search; `Enter` opens a result.
- `Ctrl-P` — show an item's type, size, owner, group, dates, and permissions. Permissions can be changed in octal notation (`000`–`777`); symlink properties are read-only.
- `Ctrl-B` — manage persistent directory bookmarks. `A` adds the current directory, `D` removes a bookmark, and `Enter` opens it.
- `Ctrl-Q` — compare both panels and mark items that are missing or differ in type, size, or modification date.
- `Ctrl-U` — calculate the selected directory's size recursively. Free and total filesystem space appear along the bottom of each panel.
- `Ctrl-K` — calculate a checksum and compare it with the same-named file in the other panel. `Tab` switches between MD5 and SHA-1/224/256/384/512; `G` writes a checksum file for the selected algorithm.
- `Ctrl-L` — create a symbolic or hard link in the other panel; `Tab` switches the link type.
- `Ctrl-J` — add marked files to the background copy queue.
- `Ctrl-T` — open the operation queue; `P` pauses, `R` resumes, and `C` cancels a task.
- `:` — run a command through `$SHELL` in the active panel's directory.
- `Ctrl-O` — open an interactive shell in the active panel's directory.
- `F1` — keyboard help; `F2` — user menu; `F9` — main menu.
- `F3` or `v` — built-in viewer with line numbers. `F4`/`H` toggles hex mode, `F7` or `/` searches, and `N` moves to the next result. For valid JSON up to 8 MiB, `F5`/`F` enables formatting without changing the file, and `F6`/`C` toggles syntax highlighting.
- `F4` or `e` — open the selected file in an external editor (`$VISUAL`, then `$EDITOR`, defaulting to `vi`).
- `F5` — copy marked items, or the current item if none are marked, to the other panel's directory. A single item can be given a different destination name.
- `F6` — move marked items, or the current item if none are marked, to the other panel's directory. A single item can also be renamed at the destination.
- `F7` — create an item in the active panel. A name without `/` creates an empty file; a name containing `/` creates a directory and any missing parent directories (`mkdir -p`). Existing files are not overwritten.
- `F8` — delete marked items, or the current item if none are marked, after confirmation.
- `F11` — switch the active panel between file list, directory tree, information, and quick preview.
- `F12` — compare both panels' directories recursively.
- `Ctrl-Y` — show a summary, then synchronize one way to the other panel; extra files at the destination remain.
- `Ctrl-N` — open a configured SFTP or FTP panel.
- `Esc` or `F10` — open the exit confirmation in the main view. If quick search is active, the first `Esc` clears it. In dialogs, `Esc` cancels the current action.
- `Ctrl-C` — exit immediately.

In terminals that support SGR mouse mode, the mouse can select a panel or file, open an item with a double-click, and scroll a list or preview with the wheel.

While an external editor is running, Twin Commander gives it the normal terminal. When the editor exits, Twin Commander restores its interface and refreshes the active panel. `VISUAL` and `EDITOR` may include arguments, for example `EDITOR="code --wait"`.

Commands run through `:` display their normal terminal output and exit status. Twin Commander waits for `Enter` so the output remains visible before returning to the panels. The exit status then remains visible in the status bar.

Press `Enter` on a `.zip`, `.tar`, `.tar.gz`, `.tgz`, `.tar.bz2`, `.tbz2`, `.tar.xz`, or `.txz` archive to open it as a temporary read-only panel. Files can be copied from there to the other panel. Archive support uses `tar` and `unzip` and rejects absolute paths and `..` entries before extraction.

By default, PDFs, images, and media files are opened with the system `open` command on macOS or `xdg-open` on other systems. Custom associations can be saved in `~/.config/twin-commander/associations` when that directory exists, or specified with `TWIN_COMMANDER_ASSOCIATIONS_FILE`:

```text
.pdf = "zathura"
.png = "feh --scale-down"
```

A command can include arguments; the file path is passed as a separate, quoted argument. Files without an association open in the built-in viewer.

During copying, a floating window shows progress as a percentage. If an item with the same name already exists at the destination, the application asks before overwriting it. Confirmation dialogs for overwriting, moving, and deleting a single item offer Yes, No, and All. For multiple marked items, the dialog shows the item count; confirmation applies only to the current operation and does not disable future warnings.

Copying and cross-filesystem moves can be interrupted with `Esc` or `Ctrl-C`. After an error, the current item can be retried, skipped, or the whole operation can be cancelled. Symbolic links are copied, moved, and deleted as links without modifying their targets.

Search covers subdirectories and respects the hidden-file setting. Results are limited to 5,000 items; content search skips binary files and files larger than 8 MiB. Bookmarks are stored in the selected configuration directory; their location can be overridden with `TWIN_COMMANDER_BOOKMARKS_FILE`. The regular panel comparison checks only the current, unexpanded contents of each panel and considers directories with the same name and type to match. The separate recursive comparison (`F12`) checks path, type, size, and modification date when available. It does not compare file contents byte for byte.

## SFTP/FTP panels and synchronization

Remote panels and synchronization involving a server require [rclone](https://rclone.org/install/) in `PATH`. First, use `rclone config` to set up an SFTP or FTP remote. Then press `Ctrl-N` in Twin Commander (or choose “Connect SFTP/FTP” from the main menu) and enter a path such as `remote-name:path`, for example `server:projects`. The `..` entry moves upward; at the remote root it returns to the previous local directory. Credentials remain in rclone's configuration, not in Twin Commander. For SFTP, configure server host-key verification. Plain FTP does not encrypt traffic; use SFTP or FTP with TLS configured in rclone on untrusted networks.

Remote panels support listing, previewing, editing with download and upload, creation, copying, moving, renaming, and deletion of files and directories. `F5`/`F6` work between local and remote panels and between two remote panels. Deleting a remote directory removes it recursively after the usual `F8` confirmation. A connection requires a valid rclone configuration; Twin Commander does not install one automatically.

`Ctrl-Y` shows a summary before synchronization. Copying is one way and leaves extra destination files intact. Local directories do not require rclone; remote synchronization uses `rclone copy`. `Ctrl-Q` compares only the current level, while `F12` compares directories recursively.

## Shortcut configuration

Main actions can be assigned to different keys in `shortcuts.json` in the selected configuration directory, or in a file specified by `TWIN_COMMANDER_SHORTCUTS_FILE`. For example:

```json
{
  "view": "Ctrl-V",
  "recursive_compare": "Ctrl-Q"
}
```

Each action has one shortcut. Available action names are `help`, `user_menu`, `main_menu`, `view`, `edit`, `copy`, `move`, `create`, `delete`, `exit`, `panel_mode`, `recursive_compare`, `sync`, `remote`, and `checksum`. Supported keys are `F1`–`F12`, `Esc`, `Enter`, `Tab`, single letters, and the `Ctrl-` and `Alt-` modifiers. Function keys also support `Shift-`. Duplicate or invalid assignments are rejected.

`Esc` still cancels dialogs and opens exit confirmation in the main view regardless of the configuration. Help and the bottom bar describe the default shortcuts; after reassignment, the configuration file takes precedence.

The interface has two distinct color themes: Kanso Pearl for light mode and Kanso Mist for dark mode. Their bundled TOML definitions are in `config/themes/`, in files prefixed with `light_` and `dark_`. The application loads themes at startup without recompilation. It overlays matching files from `~/.config/twin-commander/themes/` when that directory exists. Otherwise it uses the bundled files from `config/themes/` relative to the current working directory, then `share/twin-commander/themes/` or `config/themes/` next to the executable's directory. When moving the executable, move the bundled themes directory with it.

The application uses `CSI ? 996 n` preference reports and mode `2031` notifications to switch themes immediately when settings change. For older terminals, it periodically queries the background color with OSC 11. On macOS, terminals that support neither mechanism use the system appearance setting directly. On other systems, they keep the dark theme. A terminal response of “no preference” keeps the current theme.

The current theme appears on the right side of the status bar. To compare the two themes, override automatic detection at startup:

```sh
TWIN_COMMANDER_THEME=light make run
TWIN_COMMANDER_THEME=dark make run
```

## Themes and translations

“Template” refers to a color theme here, not a window-layout template. Colors and attributes are defined in TOML; panel and dialog layouts remain in Odin code. Adding a theme does not require a new package or code changes.

A custom file can contain only the values that differ from the default Kanso theme. Example from `config/themes/examples/dark_amber.toml`:

```toml
name = "My theme"

[panel_border_active]
foreground = "#E6B450"
bold = false
```

Select custom files for either appearance:

```sh
TWIN_COMMANDER_DARK_THEME=$HOME/.config/twin-commander/themes/dark_amber.toml make run
TWIN_COMMANDER_LIGHT_THEME=/absolute/path/my_light.toml make run
```

Automatic switching between light and dark modes still works. To force one mode, set `TWIN_COMMANDER_THEME=dark` or `light`. The full definitions in `config/themes/` show the available sections and fields. Colors use `"#RRGGBB"`; the `bold`, `dim`, and `underline` attributes use `true` or `false`. An invalid custom theme produces a warning and falls back to the default Kanso theme. File changes require a restart, but not recompilation. Relative paths are resolved from the current working directory; use absolute paths outside the project.

Translations are ordinary UTF-8 JSON files in `config/locales/`. Each key is the original Polish text, and its value is the translation:

```json
{
  "Gotowy": "Ready",
  "Katalog: %s": "Directory: %s"
}
```

Polish and English are available without additional files:

```sh
TWIN_COMMANDER_LANGUAGE=pl make run
TWIN_COMMANDER_LANGUAGE=en make run
```

Without this setting, the application checks `LC_ALL`, `LC_MESSAGES`, and then `LANG`. It selects English for English locales such as `en_US.UTF-8` and otherwise keeps Polish. To add a language, copy `config/locales/pl.json`, translate the values while keeping the keys, and specify the file:

```sh
TWIN_COMMANDER_LOCALE_FILE=/absolute/path/de.json make run
```

`TWIN_COMMANDER_LOCALE_FILE` takes precedence. Missing or empty values fall back to the Polish source text. Invalid JSON, non-string values, terminal control characters, or changed formatting placeholders cause the file to be rejected with a warning, leaving the default language in place. Keep `%s`, `%d`, and `%%` in the same order. The catalog does not yet support separate plural forms or changing the language while the application is running. File names, theme names, and operating-system error messages remain in their original form. Confirmation keys `Enter/T`, `Esc/N`, and `W` are the same in every language; translations change their labels. Short labels work better in narrow terminals.

## Architecture

Application entry points are in `cmd/`, and shared code is in `pkg/`. The main application is divided into the `commander`, `themes`, `fsops`, and `tui` packages. Terminal handling is in `pkg/tui/terminal/`; filesystem operations and system information also use POSIX APIs in `pkg/fsops/` and `pkg/commander/`.

Run the package tests with:

```sh
make test
```

## Additional stage: viewer and checksum enhancements

Completed enhancements:

- Format content without changing the source file, starting with `jq`-style JSON and a toggle between original and formatted views. Invalid JSON remains in the original view with a clear message.
- Highlight syntax in the viewer, beginning with JSON keys, values, numbers, and structural characters, then recognized text files.
- Preserve search, line numbers, and hex mode after adding formatting and colors.
- Switch the checksum algorithm (`Ctrl-K`) between MD5 and SHA variants such as SHA-1, SHA-256, and SHA-512, with file comparison and checksum output for the selected algorithm.
