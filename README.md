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

Każdy panel wyświetla zawartość własnego katalogu. Pierwsza kolumna panelu
zawiera przenośne ikony Unicode oznaczające katalogi oraz
popularne kategorie plików (m.in. kod, tekst, obrazy, archiwa, multimedia i dane).
Nie wymagają one czcionki Nerd Font.

Obsługiwane klawisze:

- `↑`/`↓` — zmiana zaznaczenia,
- `Enter` — wejście do zaznaczonego katalogu (wpis `..` przechodzi wyżej),
- `Tab` — przełączenie aktywnego panelu,
- `Spacja` — oznaczenie lub odznaczenie elementu i przejście do następnego wiersza,
- `F3` — otwarcie zaznaczonego pliku tylko do odczytu w zewnętrznym pagerze (`$PAGER`, domyślnie `less`),
- `F4` — otwarcie zaznaczonego pliku w zewnętrznym edytorze (`$VISUAL`, następnie `$EDITOR`, domyślnie `vi`),
- `F5` — skopiowanie oznaczonych elementów (lub bieżącego elementu, gdy nic nie oznaczono) do katalogu w drugim panelu,
- `F6` — przeniesienie oznaczonych elementów (lub bieżącego elementu, gdy nic nie oznaczono) do katalogu w drugim panelu,
- `F8` — usunięcie oznaczonych elementów (lub bieżącego elementu, gdy nic nie oznaczono) po potwierdzeniu,
- `Esc` lub `Ctrl-C` — zakończenie programu.

Na czas podglądu lub edycji Twin Commander oddaje zewnętrznemu programowi zwykły
terminal. Po zamknięciu programu wraca do interfejsu i po edycji odświeża aktywny
panel. Zmienne `PAGER`, `VISUAL` i `EDITOR` mogą zawierać również argumenty, np.
`EDITOR="code --wait"`.

Podczas kopiowania pływające okno pokazuje procentowy postęp operacji. Jeśli element
o tej samej nazwie już istnieje w panelu docelowym, program najpierw poprosi o
potwierdzenie jego nadpisania. Popupy dla nadpisywania, przenoszenia i usuwania
pojedynczego elementu oferują decyzje `Tak`, `Nie` oraz `Wszystkie`. Przy operacji
na wielu oznaczonych elementach dialog pokazuje liczebność zestawu, a potwierdzenie
dotyczy całej bieżącej operacji i nie wyłącza ostrzeżeń w przyszłości.

Interfejs ma dwa odrębne szablony kolorystyczne: Kanso Pearl dla trybu jasnego
i Kanso Mist dla trybu ciemnego. Ich definicje TOML znajdują się w
`config/themes/` w plikach z prefiksami `light_` i `dark_`. Pliki są wczytywane
i sprawdzane podczas uruchamiania programu; wybór motywów pozostaje obecnie
zahardkodowany. Program
korzysta z raportów preferencji systemowej `CSI ? 996 n` i powiadomień trybu
`2031`, aby przełączać motyw od razu po zmianie ustawień. Dla starszych
terminali okresowo odczytuje kolor tła przez OSC 11. Terminale bez obsługi obu
mechanizmów na macOS korzystają bezpośrednio z systemowego ustawienia wyglądu.
Na pozostałych systemach zachowują motyw ciemny. Odpowiedź terminala „brak
preferencji” zachowuje aktualny motyw.

Bieżący wariant jest widoczny po prawej stronie paska stanu. Do porównania obu
szablonów można pominąć automatyczne wykrywanie przy uruchomieniu:

```sh
TWIN_COMMANDER_THEME=light make run
TWIN_COMMANDER_THEME=dark make run
```

## Architektura

Punkty wejścia programów znajdują się w `cmd/`, a kod współdzielony w
`internal/`. Główna aplikacja jest podzielona na pakiety `commander`, `fsops`
i `tui`. Kod zależny od POSIX pozostaje odizolowany w `internal/tui/terminal/`.

Testy pakietu można uruchomić poleceniem:

```sh
make test
```
