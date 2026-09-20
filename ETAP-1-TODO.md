# Twin Commander — Etap 1

Legenda:

- `[x]` — zaimplementowane i przechodzi dotychczasowy zestaw testów,
- `[ ]` — pozostało do wykonania,
- `W toku` — kod jest wdrażany lub wymaga jeszcze testów celowanych.

## Nawigacja i stan panelu

- [x] `Home`, `End`, `Page Up`, `Page Down`.
- [x] `Backspace` — katalog nadrzędny.
- [x] historia katalogów osobno dla każdego panelu (`←` / `→`).
- [x] szybkie wyszukiwanie nazwy przez wpisywanie znaków.
- [x] ręczne odświeżenie panelu (`Ctrl-R`).
- [x] zachowanie kursora i oznaczeń po odświeżeniu.

## Widok, sortowanie i zaznaczanie

- [x] przełączanie ukrytych plików (`Ctrl-D`).
- [x] filtrowanie panelu po fragmencie nazwy (`/` lub `Ctrl-F`).
- [x] sortowanie według nazwy, rozszerzenia, rozmiaru i daty (`Ctrl-S`).
- [x] sortowanie malejące po przejściu pełnego cyklu.
- [x] oznaczanie grupy według maski (`+`).
- [x] odznaczanie grupy według maski (`\`).
- [x] odwracanie oznaczenia (`*`).

## Operacje na plikach

- [x] kopiowanie symlinków bez dereferencji.
- [x] przenoszenie i usuwanie symlinków bez naruszania celu linku.
- [x] wejście do katalogu wskazywanego przez symlink.
- [x] fallback `copy + delete` przy przenoszeniu między filesystemami.
- [x] anulowanie kopiowania/przenoszenia przez `Esc` lub `Ctrl-C`.
- [x] dialog błędu z opcjami Ponów / Pomiń / Przerwij.

## Testy i dokumentacja

- [x] testy sortowania, filtrów, historii i zachowania pozycji.
- [x] testy kopiowania i usuwania symlinków.
- [x] test ścieżki fallbacku dla przenoszenia między filesystemami.
- [x] aktualizacja polskiego i angielskiego katalogu komunikatów.
- [x] aktualizacja README ze wszystkimi nowymi skrótami.
- [x] pełne `make test`, `make build` oraz `git diff --check`.
- [x] smoke test PTY: sortowanie, filtr, ukryte pliki i zamknięcie aplikacji.
- [ ] potwierdzenie zachowania w rzeczywistej sesji Ghostty.
