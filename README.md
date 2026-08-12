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

Podczas kopiowania pływające okno pokazuje procentowy postęp operacji. Jeśli plik
o tej samej nazwie już istnieje w panelu docelowym, program najpierw poprosi o
potwierdzenie jego nadpisania.

Interfejs ma domyślne motywy jasny i ciemny. Program korzysta z raportów
preferencji systemowej `CSI ? 996 n` i powiadomień trybu `2031`, aby przełączać
motyw od razu po zmianie ustawień. Dla starszych terminali okresowo odczytuje
kolor tła przez OSC 11. Terminale bez obsługi obu mechanizmów korzystają z
motywu ciemnego.

## Architektura

Punkty wejścia programów znajdują się w `cmd/`, a kod współdzielony w
`internal/`. Główna aplikacja jest podzielona na pakiety `commander`, `fsops`
i `tui`. Kod zależny od POSIX pozostaje odizolowany w `internal/tui/terminal/`.

Testy pakietu można uruchomić poleceniem:

```sh
make test
```
