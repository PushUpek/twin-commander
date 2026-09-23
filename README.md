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
- `Home`/`End`, `Page Up`/`Page Down` — początek, koniec i przewijanie panelu stronami,
- `Enter` — wejście do katalogu, otwarcie ZIP/TAR jak katalogu albo uruchomienie skojarzonego programu dla pliku (wpis `..` przechodzi wyżej),
- `Backspace` — przejście do katalogu nadrzędnego,
- `←`/`→` — poprzedni lub następny katalog w historii aktywnego panelu,
- `Tab` — przełączenie aktywnego panelu,
- `Spacja` — oznaczenie lub odznaczenie elementu i przejście do następnego wiersza,
- wpisywanie liter — szybkie wyszukiwanie nazwy od początku; `Backspace` lub `Esc` czyści wyszukiwanie,
- `+` / `\` / `*` — oznaczenie grupy według maski, odznaczenie grupy lub odwrócenie oznaczenia,
- `/` lub `Ctrl-F` — filtr aktywnego panelu po fragmencie nazwy; pusty filtr pokazuje wszystko,
- `Ctrl-D` — pokazanie lub ukrycie plików zaczynających się od kropki,
- `Ctrl-S` — następny sposób sortowania: nazwa, rozszerzenie, rozmiar, data modyfikacji; kolejny cykl odwraca kierunek,
- `Ctrl-R` — odświeżenie panelu z zachowaniem kursora i istniejących oznaczeń,
- `Alt-F7` lub `Ctrl-G` — rekurencyjne wyszukiwanie od katalogu aktywnego panelu; `Tab` w dialogu przełącza wyszukiwanie po nazwie i w treści plików, a `Enter` na wyniku przechodzi do elementu,
- `Ctrl-P` — właściwości wybranego elementu: typ, rozmiar, właściciel, grupa, daty i uprawnienia; tryb można zmienić w zapisie ósemkowym (`000`–`777`), a dla symlinków właściwości są tylko do odczytu,
- `Ctrl-B` — trwałe zakładki katalogów; `A` dodaje bieżący katalog, `D` usuwa zakładkę, a `Enter` ją otwiera,
- `Ctrl-Q` — porównanie obu paneli i oznaczenie elementów brakujących lub różniących się typem, rozmiarem albo datą modyfikacji,
- `Ctrl-U` — rekurencyjne obliczenie rozmiaru zaznaczonego katalogu; wolne i całkowite miejsce systemu plików jest widoczne na dolnej krawędzi każdego panelu,
- `Ctrl-K` — suma kontrolna i porównanie z plikiem o tej samej nazwie w drugim panelu; `Tab` przełącza MD5 oraz SHA-1/224/256/384/512, a `G` zapisuje plik sumy dla wybranego algorytmu,
- `Ctrl-L` — utworzenie w drugim panelu linku symbolicznego lub twardego; `Tab` przełącza rodzaj linku,
- `Ctrl-J` — dodanie zaznaczonych plików do kolejki kopiowania w tle,
- `Ctrl-T` — kolejka operacji; `P` pauzuje, `R` wznawia, a `C` anuluje zadanie,
- `:` — wykonanie polecenia przez `$SHELL` w katalogu aktywnego panelu,
- `Ctrl-O` — otwarcie interaktywnej powłoki w katalogu aktywnego panelu,
- `F1` — pomoc klawiaturowa, `F2` — menu użytkownika, `F9` — menu główne,
- `F3` lub `v` — wbudowany podgląd z numerami linii; `F4`/`H` przełącza tryb hex, `F7` lub `/` wyszukuje, a `N` przechodzi do następnego wyniku. Dla poprawnego JSON-a do 8 MiB `F5`/`F` włącza formatowanie bez zmiany pliku, a `F6`/`C` przełącza kolorowanie składni,
- `F4` lub `e` — otwarcie zaznaczonego pliku w zewnętrznym edytorze (`$VISUAL`, następnie `$EDITOR`, domyślnie `vi`),
- `F5` — skopiowanie oznaczonych elementów (lub bieżącego elementu, gdy nic nie oznaczono) do katalogu w drugim panelu; dla pojedynczego elementu pozwala ustawić nazwę kopii,
- `F6` — przeniesienie oznaczonych elementów (lub bieżącego elementu, gdy nic nie oznaczono) do katalogu w drugim panelu; dla pojedynczego elementu pozwala też zmienić nazwę docelową,
- `F7` — tworzenie w aktywnym panelu: nazwa bez `/` tworzy pusty plik, z `/` katalog wraz z brakującymi katalogami nadrzędnymi (`mkdir -p`); istniejące pliki nie są nadpisywane,
- `F8` — usunięcie oznaczonych elementów (lub bieżącego elementu, gdy nic nie oznaczono) po potwierdzeniu,
- `F11` — przełączenie aktywnego panelu między listą plików, drzewem katalogów, informacjami i szybkim podglądem,
- `F12` — rekurencyjne porównanie katalogów obu paneli,
- `Ctrl-Y` — jednokierunkowa synchronizacja do drugiego panelu po pokazaniu podsumowania; dodatkowe pliki u celu pozostają,
- `Ctrl-N` — otwarcie skonfigurowanego panelu SFTP/FTP,
- `Esc` lub `F10` — otwarcie dialogu potwierdzenia zakończenia programu w głównym widoku; gdy aktywne jest szybkie wyszukiwanie, pierwsze `Esc` je czyści. W dialogach `Esc` anuluje bieżącą czynność.
- `Ctrl-C` — natychmiastowe zakończenie programu.

Mysz pozwala wskazać panel i plik, otworzyć element podwójnym kliknięciem oraz
przewijać listę lub podgląd kółkiem w terminalach obsługujących SGR mouse.

Na czas edycji Twin Commander oddaje zewnętrznemu programowi zwykły terminal.
Po zamknięciu programu wraca do interfejsu i odświeża aktywny panel. Zmienne
`VISUAL` i `EDITOR` mogą zawierać również argumenty, np.
`EDITOR="code --wait"`.

Polecenia uruchamiane przez `:` pokazują zwykłe wyjście terminala oraz kod
zakończenia. Twin Commander czeka na `Enter`, dzięki czemu wynik nie znika przed
powrotem do paneli. Kod zakończenia pozostaje następnie widoczny na pasku stanu.

Archiwa `.zip`, `.tar`, `.tar.gz`, `.tgz`, `.tar.bz2`, `.tbz2`, `.tar.xz` i
`.txz` są otwierane przez `Enter` jako tymczasowy panel tylko do odczytu. Można
z niego kopiować pliki do drugiego panelu. Obsługa korzysta z poleceń `tar` i
`unzip`, a przed rozpakowaniem odrzuca ścieżki absolutne oraz elementy `..`.

Domyślnie pliki PDF, obrazy i multimedia są otwierane przez systemowy `open`
na macOS albo `xdg-open` na pozostałych systemach. Własne skojarzenia można
zapisać w pliku `twin-commander/associations` w katalogu konfiguracji użytkownika
lub wskazać przez `TWIN_COMMANDER_ASSOCIATIONS_FILE`:

```text
.pdf = "zathura"
.png = "feh --scale-down"
```

Polecenie może zawierać argumenty; ścieżka pliku jest przekazywana jako osobny,
cytowany argument. Brak skojarzenia powoduje otwarcie wbudowanego podglądu.

Podczas kopiowania pływające okno pokazuje procentowy postęp operacji. Jeśli element
o tej samej nazwie już istnieje w panelu docelowym, program najpierw poprosi o
potwierdzenie jego nadpisania. Popupy dla nadpisywania, przenoszenia i usuwania
pojedynczego elementu oferują decyzje `Tak`, `Nie` oraz `Wszystkie`. Przy operacji
na wielu oznaczonych elementach dialog pokazuje liczebność zestawu, a potwierdzenie
dotyczy całej bieżącej operacji i nie wyłącza ostrzeżeń w przyszłości.
Kopiowanie oraz wykonywane między różnymi systemami plików przenoszenie można
przerwać klawiszem `Esc` lub `Ctrl-C`. Błąd operacji pozwala ponowić bieżący
element, pominąć go albo przerwać cały zestaw. Linki symboliczne są kopiowane,
przenoszone i usuwane jako linki, bez modyfikowania wskazywanego przez nie celu.
Wyszukiwanie obejmuje podkatalogi i respektuje ustawienie widoczności plików
ukrytych; lista jest ograniczona do 5000 wyników, a wyszukiwanie treści pomija
pliki binarne i pliki większe niż 8 MiB. Zakładki są zapisywane w katalogu
konfiguracji użytkownika; ścieżkę można nadpisać zmienną
`TWIN_COMMANDER_BOOKMARKS_FILE`. Porównanie paneli działa na ich bieżącej, nierozwijanej
rekurencyjnie zawartości; katalogi o tej samej nazwie i typie są uznawane za zgodne.
Osobne porównanie rekurencyjne (`F12`) uwzględnia ścieżkę, typ, rozmiar i — jeśli
jest dostępna — datę modyfikacji. Nie porównuje bajt po bajcie zawartości plików.

## Panele SFTP/FTP i synchronizacja

Do paneli zdalnych oraz synchronizacji z udziałem serwera potrzebny jest
[rclone](https://rclone.org/install/) dostępny w `PATH`. Najpierw skonfiguruj
połączenie poleceniem `rclone config` jako zdalny zasób typu SFTP albo FTP.
Następnie w Twin Commander naciśnij `Ctrl-N` (lub wybierz „Połącz SFTP/FTP” z
menu głównego) i podaj ścieżkę `nazwa-zasobu:ścieżka`, np. `serwer:projekty`.
Wpis `..` pozwala wracać w górę; na korzeniu zasobu wraca do poprzedniego
katalogu lokalnego. Dane uwierzytelniające pozostają w konfiguracji rclone,
nie w Twin Commander. Dla SFTP warto skonfigurować weryfikację klucza serwera.
Zwykłe FTP nie szyfruje połączenia; do przesyłania danych w niezaufanej sieci
użyj SFTP albo FTP z TLS skonfigurowanym w rclone.

Zdalny panel obsługuje listowanie, podgląd, edycję z pobraniem i odesłaniem
pliku, tworzenie, kopiowanie, przenoszenie, zmianę nazwy i usuwanie plików oraz
katalogów. `F5`/`F6` działają między panelem lokalnym i zdalnym oraz między
dwoma panelami zdalnymi. Usunięcie katalogu zdalnego usuwa go rekurencyjnie,
po zwykłym potwierdzeniu `F8`. Połączenie wymaga poprawnej konfiguracji rclone;
program nie instaluje jej automatycznie.

`Ctrl-Y` pokazuje podsumowanie przed synchronizacją. Kopiowanie jest
jednokierunkowe i nie usuwa dodatkowych plików u celu. Dla katalogów lokalnych
nie wymaga rclone; dla zdalnych używa polecenia `rclone copy`. Zwykłe `Ctrl-Q`
porównuje tylko bieżący poziom, a `F12` porównuje katalogi rekurencyjnie.

## Konfiguracja skrótów

Główne akcje można przypisać do innych klawiszy w pliku
`twin-commander/shortcuts.json` w katalogu konfiguracji użytkownika albo w
pliku wskazanym przez `TWIN_COMMANDER_SHORTCUTS_FILE`. Przykład:

```json
{
  "view": "Ctrl-V",
  "recursive_compare": "Ctrl-Q"
}
```

Każda akcja ma jeden skrót. Dostępne nazwy: `help`, `user_menu`, `main_menu`,
`view`, `edit`, `copy`, `move`, `create`, `delete`, `exit`, `panel_mode`,
`recursive_compare`, `sync`, `remote`, `checksum`. Akceptowane są klawisze
`F1`–`F12`, `Esc`, `Enter`, `Tab`, pojedyncze litery i modyfikatory `Ctrl-`,
`Alt-`, a dla klawiszy funkcyjnych także `Shift-`. Dublujące się lub
niepoprawne przypisania są odrzucane.
`Esc` nadal anuluje dialogi oraz — w głównym widoku — otwiera potwierdzenie
wyjścia niezależnie od konfiguracji. Pomoc i pasek dolny opisują domyślne
skróty; po zmianie przypisań obowiązuje plik konfiguracyjny.

Interfejs ma dwa odrębne szablony kolorystyczne: Kanso Pearl dla trybu jasnego
i Kanso Mist dla trybu ciemnego. Ich definicje TOML znajdują się w
`config/themes/` w plikach z prefiksami `light_` i `dark_`. Aplikacja wczytuje
domyślne i własne motywy z plików TOML przy uruchomieniu, bez rekompilacji.
Domyślnych plików szuka w `config/themes/` względem bieżącego katalogu, a potem
w katalogu `config/themes/` obok katalogu z binarką. Przy przenoszeniu binarki
trzeba przenieść również katalog `config/themes/`. Program
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
`bold`, `dim`, `underline` jako `true` lub `false`. Niepoprawny plik własnego motywu powoduje
ostrzeżenie i użycie domyślnego Kanso. Zmiany plików wymagają ponownego uruchomienia,
ale nie rekompilacji.
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
`pkg/`. Główna aplikacja jest podzielona na pakiety `commander`, `themes`,
`fsops` i `tui`. Kod zależny od POSIX pozostaje odizolowany w `pkg/tui/terminal/`.

Testy pakietu można uruchomić poleceniem:

```sh
make test
```

## Dodatkowy etap: rozbudowa podglądu i sum kontrolnych

Zrealizowane rozszerzenia:

- formatowanie treści bez zmiany pliku źródłowego — najpierw JSON w stylu `jq`, z możliwością przełączenia między widokiem oryginalnym i sformatowanym; błędny JSON pozostaje w widoku oryginalnym z czytelnym komunikatem,
- kolorowanie składni w podglądzie, zaczynając od JSON (klucze, wartości, liczby i znaki strukturalne), a następnie dla rozpoznanych plików tekstowych,
- zachowanie wyszukiwania, numerów linii i trybu hex także po dodaniu formatowania oraz kolorów,
- możliwość przełączania algorytmu sumy kontrolnej (`Ctrl-K`) między MD5 a wariantami SHA (np. SHA-1, SHA-256 i SHA-512), z porównywaniem plików i zapisem sumy dla wybranego algorytmu.
