# Simple build file. Run:  make          (build everything)
#                          make run      (build + run every demo)
#                          make clean
CC      = gcc
CFLAGS  = -w
SRC     = src
IN      = input

all: p01 p03 p05 p06 p07 p08 p12 p18 p23 p24

p01: ; flex -o build/p01.c $(SRC)/p01_stripper.l   && $(CC) $(CFLAGS) build/p01.c -o p01
p03: ; flex -o build/p03.c $(SRC)/p03_classifier.l && $(CC) $(CFLAGS) build/p03.c -o p03
p05: ; flex -o build/p05.c $(SRC)/p05_numbers.l    && $(CC) $(CFLAGS) build/p05.c -o p05
p06: ; flex -o build/p06.c $(SRC)/p06_literals.l   && $(CC) $(CFLAGS) build/p06.c -o p06
p07: ; flex -o build/p07.c $(SRC)/p07_regex.l      && $(CC) $(CFLAGS) build/p07.c -o p07
p08: ; flex -o build/p08.c $(SRC)/p08_operators.l  && $(CC) $(CFLAGS) build/p08.c -o p08
p12: ; $(CC) $(CFLAGS) $(SRC)/p12_nfa2dfa.c -o p12
p18: ; flex -o build/p18.c $(SRC)/p18_symtab.l     && $(CC) $(CFLAGS) build/p18.c -o p18

p23:
	cd $(SRC) && bison -d p23_calc.y && flex -o p23_lex.c p23_calc.l && \
	$(CC) $(CFLAGS) p23_calc.tab.c p23_lex.c -o ../p23

p24:
	cd $(SRC) && bison -d p24_calc.y && flex -o p24_lex.c p24_calc.l && \
	$(CC) $(CFLAGS) p24_calc.tab.c p24_lex.c -o ../p24

clean:
	rm -f p01 p03 p05 p06 p07 p08 p12 p18 p23 p24 build/*.c \
	      $(SRC)/*.tab.c $(SRC)/*.tab.h $(SRC)/p2*_lex.c
