# CSE314 — Compiler Design Lab

Worked solutions for the practice problem set: Flex lexical analysers, subset construction,
symbol table integration, and Bison parsers with error recovery.

**Solved:** problems 1, 3, 5, 6, 7, 8, 12, 18, 23, 24.

📖 **[GUIDE.md](GUIDE.md)** — full explanation of the logic and the Flex/Bison syntax behind
every program, plus sample input and expected output for each.

## Layout

```
src/      solution sources (.l = Flex, .y = Bison, .c = plain C)
input/    sample input for every program
build/    generated scanners land here (gitignored)
Makefile  builds everything
```

| # | Problem | File |
|---|---|---|
| 1 | Whitespace collapser + comment stripper | `src/p01_stripper.l` |
| 3 | Token classifier (also covers Problem 9: line/column tracking) | `src/p03_classifier.l` |
| 5 | Integer / float / malformed number classifier | `src/p05_numbers.l` |
| 6 | String and character literals with escape checking | `src/p06_literals.l` |
| 7 | Recogniser for `a*`, `a*b+`, `(ab)*`, `abb` | `src/p07_regex.l` |
| 8 | Operator validator | `src/p08_operators.l` |
| 12 | NFA → DFA by subset construction | `src/p12_nfa2dfa.c` |
| 18 | Scoped symbol table integrated with a Flex lexer | `src/p18_symtab.l` |
| 23 | Bison calculator with variables | `src/p23_calc.y`, `src/p23_calc.l` |
| 24 | Panic-mode syntax error recovery | `src/p24_calc.y`, `src/p24_calc.l` |

## Requirements

```bash
sudo apt install flex bison gcc make      # Debian / Ubuntu / WSL
```

## Build and run

```bash
make

./p01 input/in01.c          ./p12 < input/in12.txt
./p03 input/in03.c          ./p18 input/in18.c
./p05 input/in05.txt        ./p23 < input/in23.txt
./p06 input/in06.txt        ./p24 < input/in24.txt
./p07 input/in07.txt
./p08 input/in08.txt

make clean
```

To build one program by hand instead:

```bash
flex  src/p05_numbers.l && gcc lex.yy.c -o p05        # a Flex-only solution
bison -d src/p23_calc.y && flex src/p23_calc.l \
      && gcc p23_calc.tab.c lex.yy.c -o p23           # a Flex + Bison solution
```

## Notes

- Every `.l` file uses `%option noyywrap`, so you do **not** need to link `-lfl`.
- `input/in07.txt` relies on `$` (end of line). If you edit it on Windows, run `dos2unix` on it
  first — a stray `\r` will break the anchored patterns.
- `src/p24_calc.y` uses `%define parse.error verbose`. On Bison older than 3.0, replace that
  line with `%error-verbose`.
