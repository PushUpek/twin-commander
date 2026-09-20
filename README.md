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
- `F3` lub `v` — otwarcie zaznaczonego pliku tylko do odczytu w zewnętrznym pagerze (`$PAGER`, domyślnie `less`),
- `F4` lub `e` — otwarcie zaznaczonego pliku w zewnętrznym edytorze (`$VISUAL`, następnie `$EDITOR`, domyślnie `vi`),
- `F5` — skopiowanie oznaczonych elementów (lub bieżącego elementu, gdy nic nie oznaczono) do katalogu w drugim panelu; dla pojedynczego elementu pozwala ustawić nazwę kopii,
- `F6` — przeniesienie oznaczonych elementów (lub bieżącego elementu, gdy nic nie oznaczono) do katalogu w drugim panelu; dla pojedynczego elementu pozwala też zmienić nazwę docelową,
- `F7` — tworzenie w aktywnym panelu: nazwa bez `/` tworzy pusty plik, z `/` katalog wraz z brakującymi katalogami nadrzędnymi (`mkdir -p`); istniejące pliki nie są nadpisywane,
- `F8` — usunięcie oznaczonych elementów (lub bieżącego elementu, gdy nic nie oznaczono) po potwierdzeniu,
- `Esc` lub `F10` — otwarcie dialogu potwierdzenia zakończenia programu.
- `Ctrl-C` — natychmiastowe zakończenie programu.

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
`config/themes/` w plikach z prefiksami `light_` i `dark_`. Domyślne motywy są dołączone do programu podczas budowania, więc działają także
po uruchomieniu z innego katalogu. Własne motywy są wczytywane z pliku przy
uruchomieniu. Program
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

## Skórki i tłumaczenia

„Template” oznacza tutaj motyw kolorystyczny, a nie szablon układu okien.
Kolory i atrybuty są w TOML; układ paneli i dialogów pozostaje w kodzie Odin.
Nie trzeba tworzyć nowego pakietu ani zmieniać kodu, żeby dodać skórkę.

Własny plik może zawierać wyłącznie zmiany względem domyślnego Kanso.
Przykład w `config/themes/examples/dark_amber.toml`:

```toml
name = "Mój motyw"

[panel_border_active]
foreground = "#E6B450"
bold = false
```

Wybór plików dla obu wariantów:

```sh
TWIN_COMMANDER_DARK_THEME=config/themes/examples/dark_amber.toml make run
TWIN_COMMANDER_LIGHT_THEME=/pełna/ścieżka/moj_jasny.toml make run
```

Automatyczne przełączanie jasny/ciemny dalej działa. Aby wymusić wariant,
dodaj `TWIN_COMMANDER_THEME=dark` lub `light`. Dostępne sekcje i pola pokazują
pełne definicje w `config/themes/`. Kolory zapisujemy jako `"#RRGGBB"`, a atrybuty
`bold`, `dim`, `underline` jako `true` lub `false`. Niepoprawny plik powoduje
ostrzeżenie i użycie domyślnego Kanso. Zmiany plików wymagają ponownego uruchomienia.
Ścieżki względne liczone są od bieżącego katalogu; poza projektem użyj pełnych ścieżek.

Tłumaczenia są zwykłymi plikami JSON UTF-8 w `config/locales/`.
Kluczem jest oryginalny polski tekst, a wartością jego tłumaczenie:

```json
{
  "Gotowy": "Ready",
  "Katalog: %s": "Directory: %s"
}
```

Polski i angielski są dostępne bez dodatkowych plików:

```sh
TWIN_COMMANDER_LANGUAGE=pl make run
TWIN_COMMANDER_LANGUAGE=en make run
```

Bez tego ustawienia aplikacja sprawdza kolejno `LC_ALL`, `LC_MESSAGES`, `LANG`.
Dla angielskiego (np. `en_US.UTF-8`) wybiera angielski; dla pozostałych języków
zachowuje polski. Aby dodać język, skopiuj `config/locales/pl.json`, przetłumacz
wartości, zachowując klucze, i wskaż plik:

```sh
TWIN_COMMANDER_LOCALE_FILE=/pełna/ścieżka/de.json make run
```

Plik wskazany przez `TWIN_COMMANDER_LOCALE_FILE` ma pierwszeństwo. Brakujące lub
puste wartości wracają do polskiego tekstu. Niepoprawny JSON, wartości inne niż
tekst, znaki sterujące terminalem oraz zmienione znaczniki formatowania powodują
odrzucenie pliku z ostrzeżeniem i pozostawienie domyślnego języka.
Zachowaj `%s`, `%d` i `%%` w tej samej kolejności. Katalog nie obsługuje jeszcze
osobnych form liczby mnogiej ani zmiany języka podczas działania. Nazwy plików,
nazwy motywów i komunikaty błędów systemu operacyjnego pozostają oryginalne.
Klawisze potwierdzania `Enter/T`, `Esc/N` i `W` są takie same w każdym języku;
tłumaczenia zmieniają ich opisy. Krótkie etykiety mieszczą się lepiej w wąskim terminalu.

## Architektura

Punkty wejścia programów znajdują się w `cmd/`, a kod współdzielony w
`internal/`. Główna aplikacja jest podzielona na pakiety `commander`, `fsops`
i `tui`. Kod zależny od POSIX pozostaje odizolowany w `internal/tui/terminal/`.

Testy pakietu można uruchomić poleceniem:

```sh
make test
```
