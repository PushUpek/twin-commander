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

Aktualny prototyp wyświetla dwa testowe panele. `Tab` przełącza aktywny panel,
strzałki `↑`/`↓` zmieniają zaznaczenie, a `Esc` lub `Ctrl-C` kończy program.

## TUI

Warstwa terminalowa i renderer znajdują się w osobnym, wewnętrznym pakiecie
`tui/`. Aplikacja korzysta wyłącznie z jego publicznej fasady, natomiast kod
zależny od POSIX jest odizolowany w `tui/terminal/`.

Testy pakietu można uruchomić poleceniem:

```sh
make test
```
