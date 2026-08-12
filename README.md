# Twin Commander

Twin Commander to nowoczesny, dwupanelowy menedżer plików inspirowany Norton Commanderem, napisany w języku [Odin](https://odin-lang.org/).

## Budowanie

Wymagany jest kompilator Odin dostępny w `PATH`.

```sh
make
```

Program zostanie zbudowany w katalogu `build/`.

## Uruchamianie

```sh
make run
```

Każdy panel wyświetla zawartość własnego katalogu. Obsługiwane klawisze:

- `↑`/`↓` — zmiana zaznaczenia,
- `Enter` — wejście do zaznaczonego katalogu (wpis `..` przechodzi wyżej),
- `Tab` — przełączenie aktywnego panelu,
- `F5` — skopiowanie zaznaczonego pliku do katalogu w drugim panelu,
- `Esc` lub `Ctrl-C` — zakończenie programu.

Podczas kopiowania pasek stanu pokazuje procentowy postęp operacji. Istniejący
plik o tej samej nazwie w panelu docelowym zostanie zastąpiony.

## Architektura

Punkty wejścia programów znajdują się w `cmd/`, a kod współdzielony w
`internal/`. Główna aplikacja jest podzielona na pakiety `commander`, `fsops`
i `tui`. Kod zależny od POSIX pozostaje odizolowany w `internal/tui/terminal/`.

Testy pakietu można uruchomić poleceniem:

```sh
make test
```
