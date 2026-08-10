# CSE314 — Worked Solutions & Explanations
### Problems 1, 3, 5, 6, 7, 8, 12, 18, 23, 24

Full source is in `src/`, sample inputs in `input/`. Everything below explains *why* the code
looks the way it does, not just what to type.

---

## 0. The two things you must internalise first

### 0.1 Anatomy of a `.l` (Flex) file

```
%{
   ... plain C: #includes, globals, helper functions ...
%}
   ... options and named definitions ...
%%
   pattern   { C action }
   pattern   { C action }
%%
   ... user C code, usually main() ...
```

| Thing | Meaning |
|---|---|
| `yytext` | char* holding the text that just matched |
| `yyleng` | its length |
| `yyin` | the `FILE*` being scanned (default `stdin`) |
| `yylex()` | runs the scanner; returns when an action does `return` |
| `%option noyywrap` | "there is only one input file" — saves you writing `yywrap()` |
| `%option yylineno` | Flex maintains `yylineno` for you |
| `%x NAME` | declares an **exclusive start condition** (a scanner "mode") |
| `BEGIN(NAME)` | switch to that mode; `BEGIN(INITIAL)` returns to normal |

### 0.2 The two disambiguation rules — everything in Section A depends on these

1. **Longest match wins.** If two patterns can match at the current position, the one that
   consumes more characters is chosen.
2. **Earliest rule wins on a tie.** If two patterns match the *same* number of characters,
   the one written **first** in the file is used.

This is why keyword rules go before identifier rules, why `==` is written before `=`, and why
the "malformed number" rule can be placed *after* the good rules and still win on `3.14.5`
(it matches 6 characters, `FLOAT` only matches 4).

### 0.3 Flex regex syntax cheat-sheet

```
x        literal x                  [abc]     one of a,b,c
.        any char except newline     [^abc]    any char NOT a,b,c
r*       zero or more                r+        one or more
r?       optional                    r{2,}     two or more
r|s      alternation                 (r)       grouping
"..."    literal string (no metachars inside)
^r       r at start of line          r$        r at end of line (before \n)
{NAME}   expands a named definition  <<EOF>>   end of file
\n \t \\ escapes
```

### 0.4 Build commands

```bash
flex  foo.l              # -> lex.yy.c
gcc   lex.yy.c -o foo    # add -lfl if you did NOT use %option noyywrap
./foo input.txt

bison -d bar.y           # -> bar.tab.c and bar.tab.h
flex  bar.l              # -> lex.yy.c  (it #includes bar.tab.h)
gcc   bar.tab.c lex.yy.c -o bar
```

Or just `make` from the project root (a `Makefile` is included).

---

## Problem 1 — Whitespace collapser + comment stripper
**File:** `src/p01_stripper.l` **Input:** `input/in01.c`

### Logic
Three jobs at once, and they interact:

1. **Comments** are not a single regex problem — a `/* ... */` comment can span lines and can
   contain anything. The clean way is a **start condition**: on `/*` switch to mode `BLOCK`,
   where every character is thrown away until `*/` sends you back to `INITIAL`.
2. **String literals must be protected.** `"hello   world"` keeps its inner spaces, and a `//`
   inside a string is *not* a comment. So the string-literal rule sits above the whitespace rule.
3. **Collapsing whitespace** naively (`[ \t\n]+ { printf(" "); }`) gives you double spaces
   whenever a comment sat between two whitespace runs. Instead I set a flag:

```c
static int pending = 0;   /* whitespace seen but not yet printed */
static int started = 0;   /* have we printed anything yet? */
static void emit(const char *s) {
    if (pending && started) putchar(' ');   /* at most one space, never leading */
    pending = 0; fputs(s, stdout); started = 1;
}
```

Whitespace and both kinds of comment only ever *set* `pending`. The space is actually printed
lazily, right before the next real character. That guarantees exactly one separator.

### Key rules
```lex
%x LINE BLOCK

"//"                { BEGIN(LINE); }
<LINE>\n            { BEGIN(INITIAL); pending = 1; }
<LINE>.             { }
"/*"                { BEGIN(BLOCK); }
<BLOCK>"*/"         { BEGIN(INITIAL); pending = 1; }
<BLOCK>\n           { }
<BLOCK>.            { }
<BLOCK><<EOF>>      { fprintf(stderr, "Error: unterminated block comment\n"); yyterminate(); }
\"([^"\\\n]|\\.)*\" { emit(yytext); }
[ \t\r\n]+          { pending = 1; }
.                   { emit(yytext); }
```
`\"([^"\\\n]|\\.)*\"` is the standard C-string pattern: *"a quote, then any number of
(non-quote-non-backslash chars, or a backslash followed by anything), then a quote."*
The `\\.` alternative is what makes `"say \"hi\""` work.

### Input (`input/in01.c`)
```c
// this is a line comment
int    main( void )
{
    /* a block
       comment spanning lines */
    int   x =   10;
    printf( "hello   world\n" );   // trailing comment
    return    0;
}
```

### Output
```
int main( void ) { int x = 10; printf( "hello   world\n" ); return 0; }
```
Note the spaces *inside* the string survived — that is the point of rule ordering.

---

## Problem 3 — Token classifier (KEYWORD / IDENTIFIER / NUMBER / OPERATOR / PUNCTUATION)
**File:** `src/p03_classifier.l` **Input:** `input/in03.c`

### Logic
- There is **no separate keyword pattern**. `int` and `count` match the same regex
  `[A-Za-z_][A-Za-z0-9_]*`. You match once as an identifier and then ask a lookup function
  `is_keyword()` whether the lexeme is in the reserved word list. (Writing 32 separate keyword
  rules also works and is faster, but the table is what a real compiler does — and it's the same
  idea you reuse for the symbol table in Problem 18.)
- Multi-character operators must be listed **before** single characters, otherwise `>=` scans as
  `>` then `=`. (Longest-match would actually save you here, but being explicit is safer once
  you add definitions.)
- I also track `line` and `col`, which makes this file a solution to Problem 9 as well.
  `col += yyleng` after every token; `\n` resets `col = 1` and bumps `line`.

### Key definitions
```lex
ID    [A-Za-z_][A-Za-z0-9_]*
NUM   [0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?
OP    "=="|"!="|"<="|">="|"&&"|"||"|"++"|"--"|"+="|"-="|"*="|"/="|"<<"|">>"|"->"|[-+*/%=<>!&|^~]
PUNC  [(){}\[\];,.:?]
```
Inside a character class `[-+*/...]` the `-` is written **first** so it is a literal hyphen and
not a range. The block-comment eater `"/*"([^*]|\*+[^*/])*\*+"/"` is the classic one-line
version: *"anything that isn't a star, or a run of stars not followed by a slash."*

### Input (`input/in03.c`)
```c
int main() {
    float rate = 3.14;
    int count = 10;
    if (count >= 5 && rate != 0) {
        count++;
        rate = rate * 2.0;
    }
    return 0;
}
```

### Output
```
LN   COL  LEXEME         CLASS
-------------------------------------------
1    1    int            KEYWORD
1    5    main           IDENTIFIER
1    9    (              PUNCTUATION
1    10   )              PUNCTUATION
1    12   {              PUNCTUATION
2    5    float          KEYWORD
2    11   rate           IDENTIFIER
2    16   =              OPERATOR
2    18   3.14           NUMBER
2    22   ;              PUNCTUATION
3    5    int            KEYWORD
3    9    count          IDENTIFIER
3    15   =              OPERATOR
3    17   10             NUMBER
3    19   ;              PUNCTUATION
4    5    if             KEYWORD
4    8    (              PUNCTUATION
4    9    count          IDENTIFIER
4    15   >=             OPERATOR
4    18   5              NUMBER
4    20   &&             OPERATOR
4    23   rate           IDENTIFIER
4    28   !=             OPERATOR
4    31   0              NUMBER
4    32   )              PUNCTUATION
4    34   {              PUNCTUATION
5    9    count          IDENTIFIER
5    14   ++             OPERATOR
5    16   ;              PUNCTUATION
6    9    rate           IDENTIFIER
6    14   =              OPERATOR
6    16   rate           IDENTIFIER
6    21   *              OPERATOR
6    23   2.0            NUMBER
6    26   ;              PUNCTUATION
7    5    }              PUNCTUATION
8    5    return         KEYWORD
8    12   0              NUMBER
8    13   ;              PUNCTUATION
9    1    }              PUNCTUATION
```

---

## Problem 5 — Integer / float / malformed number
**File:** `src/p05_numbers.l` **Input:** `input/in05.txt`

### Logic
The whole problem is **making the error pattern longer than the good pattern**, so that
longest-match automatically flags bad input.

```lex
INT     [0-9]+
FLOAT   ([0-9]+\.[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?|[0-9]+[eE][+-]?[0-9]+
BAD     [0-9]+[A-Za-z0-9._]*|\.[0-9]+[A-Za-z0-9._]*
```

- `FLOAT` has three shapes: `3.14`, `.5`, and exponent-only `1e9`. The exponent group
  `([eE][+-]?[0-9]+)?` is optional and **requires at least one digit after the sign** — that is
  what makes `1e` invalid.
- `BAD` is "a digit-run followed by any junk made of letters/digits/dots/underscores".
  On `3.14.5` it consumes **6** characters while `FLOAT` only consumes 4 → `BAD` wins even
  though it is written last. On `3.14` both would match 4, so the tie is broken by order, and
  `FLOAT` is written first → correct.
- `BAD` cannot swallow identifiers because it must **start** with a digit or a dot.

Rule order in the file: `FLOAT`, `INT`, `BAD`, `ID`, whitespace, catch-all `.`.

### Input (`input/in05.txt`)
```
42
0
3.14
3.14e-2
.5
6.02E23
3.14.5
12abc
1e
total
```

### Output
```
42             INTEGER   (line 1)
0              INTEGER   (line 2)
3.14           FLOAT     (line 3)
3.14e-2        FLOAT     (line 4)
.5             FLOAT     (line 5)
6.02E23        FLOAT     (line 6)
3.14.5         ERROR: malformed number (line 7)
12abc          ERROR: malformed number (line 8)
1e             ERROR: malformed number (line 9)
total          (identifier, not a number)
```

---

## Problem 6 — String and character literals with escapes
**File:** `src/p06_literals.l` **Input:** `input/in06.txt`

### Logic
Two layers:

**Layer 1 — recognition (regex).** For each literal kind, write the *good* pattern and then a
shorter *fallback* pattern with no closing quote. Longest-match picks the good one whenever the
literal is properly closed, and falls back to the error rule when it isn't.

```lex
\"([^"\\\n]|\\.)*\"        /* good string          */
\"([^"\\\n]|\\.)*          /* unterminated string  */
'([^'\\\n]|\\.)'           /* good char, exactly one unit */
'([^'\\\n]|\\.){2,}'       /* 'abc' -> multi-character constant */
''                         /* '' -> empty */
'([^'\\\n]|\\.)*           /* unterminated char */
```
Excluding `\n` from the character class is what stops a broken string from eating the rest of
the file — the fallback rule stops at end of line and reports the error there.

**Layer 2 — validation (C code).** The regex accepts `\q`, because `\\.` means "backslash plus
*anything*". Whether an escape is *legal* is a semantic check, so it lives in an action:

```c
static const char *legal = "ntrbfva\\'\"?0";
if (s[i] == '\\' && !strchr(legal, s[i+1]))
    printf("      warning: unknown escape sequence \\%c\n", s[i+1]);
```
That split — regex for shape, C for meaning — is the general pattern for all of lexical analysis.

### Input (`input/in06.txt`)
```
"hello world"
"tab\there and newline\n"
"bad escape \q inside"
"unterminated string
'a'
'\n'
'\q'
'abc'
'x
```

### Output
```
"hello world"            STRING literal  (line 1)
"tab\there and newline\n" STRING literal  (line 2)
"bad escape \q inside"   STRING literal  (line 3)
      warning: unknown escape sequence \q on line 3
"unterminated string     ERROR: unterminated string (line 4)
'a'                      CHAR literal    (line 5)
'\n'                     CHAR literal    (line 6)
'\q'                     CHAR literal    (line 7)
      warning: unknown escape sequence \q on line 7
'abc'                    ERROR: multi-character char constant (line 8)
'x                       ERROR: unterminated char constant (line 9)
```

---

## Problem 7 — Which of `a*`, `a*b+`, `(ab)*`, `abb` does a string match?
**File:** `src/p07_regex.l` **Input:** `input/in07.txt`

### Logic
Two traps here.

**Trap 1 — you must match the *whole line*, not a prefix.** Plain `a*` would happily match the
leading `aa` of `aab` and call it a match. Anchor both ends: `^a+$`. In Flex, `^` means "at the
start of a line" and `$` is trailing context meaning "followed by a newline" (the `\n` is *not*
consumed, so a separate `\n { }` rule mops it up).

**Trap 2 — the four languages overlap.** `""` is in both `a*` and `(ab)*`; `ab` is in both
`(ab)*` and `a*b+` (take `a*` = `a`, `b+` = `b`); `abb` is in both `abb` and `a*b+`. Since every
anchored rule matches exactly the whole line, all candidate rules tie on length, and **rule order
decides**. So order from most specific to most general and print the full membership set in each
action:

```lex
^\n         -> a* , (ab)*            [empty string]
^abb$       -> abb , a*b+
^ab$        -> (ab)* , a*b+
^(ab)+$     -> (ab)*
^a+$        -> a*
^a*b+$      -> a*b+
^[ab]+$     -> matches none of the four
^.+$        -> not over the alphabet {a,b}
```
`^ab$` must come before `^(ab)+$`, otherwise `ab` would be reported as `(ab)*` only and you'd
miss that it is also in `a*b+`.

### Input (`input/in07.txt`) — first line is blank
```

a
aaa
b
ab
abb
abab
aab
aabb
ba
abba
abc
```

### Output
```
STRING      MATCHING PATTERNS
------------------------------------------
""         -> a*   ,  (ab)*        [empty string]
a          -> a*
aaa        -> a*
b          -> a*b+
ab         -> (ab)* ,  a*b+
abb        -> abb  ,  a*b+
abab       -> (ab)*
aab        -> a*b+
aabb       -> a*b+
ba         -> matches NONE of the four patterns
abba       -> matches NONE of the four patterns
abc        -> invalid input (not over the alphabet {a,b})
```
Sanity check `abba`: not `a*` (has b's), not `a*b+` (ends in `a`), not `(ab)*` (would need even
length in `ab` pairs — `ab`+`ba` fails), not `abb`. Correctly "none".

> **Windows warning:** if your input file has CRLF line endings, the `\r` breaks `$`. Run
> `dos2unix input/in07.txt` or add `\r?` before each `$`.

---

## Problem 8 — Operator validator
**File:** `src/p08_operators.l` **Input:** `input/in08.txt`

### Logic
Elegant trick: don't try to enumerate every *invalid* combination (there are hundreds). Instead:

1. List all **valid** operators, longest first.
2. Add one catch-all rule: *"two or more operator characters in a row"* → INVALID.

```lex
OPCHAR  [-+*/%=<>!&|^~?:]

"<<="|">>="                              -> VALID (3 chars)
"=="|"!="|"<="|">="|"&&"|"||"|"++"|"--"  -> VALID (2 chars)
"+="|"-="|...|"<<"|">>"|"->"             -> VALID (2 chars)
{OPCHAR}                                 -> VALID (1 char)
{OPCHAR}{2,}                             -> INVALID
```

Why this works, purely from the two disambiguation rules:

| Input | valid rules match | catch-all matches | winner |
|---|---|---|---|
| `==` | 2 chars | 2 chars | tie → **earlier rule** → VALID |
| `<<=` | 3 chars | 3 chars | tie → **earlier rule** → VALID |
| `+*` | 1 char (`+`) | 2 chars | **longest** → INVALID |
| `===` | 2 chars (`==`) | 3 chars | **longest** → INVALID |

That single catch-all rule is doing all the error detection.

### Input (`input/in08.txt`)
```
a + b
x == y
i++
p <= q && r >= s
n <<= 2
a +* b
x =+ y
z === w
c -> d
```

### Output
```
VALID    +    (1-char operator)    line 1
VALID    ==   (2-char operator)    line 2
VALID    ++   (2-char operator)    line 3
VALID    <=   (2-char operator)    line 4
VALID    &&   (2-char operator)    line 4
VALID    >=   (2-char operator)    line 4
VALID    <<=  (3-char assignment)  line 5
INVALID  +*   <-- malformed operator sequence, line 6
INVALID  =+   <-- malformed operator sequence, line 7
INVALID  ===  <-- malformed operator sequence, line 8
VALID    ->   (2-char operator)    line 9

Summary: 8 valid operator(s), 3 malformed sequence(s).
```

---

## Problem 12 — NFA → DFA (subset construction)
**File:** `src/p12_nfa2dfa.c` (plain C, no Flex) **Input:** `input/in12.txt`

### The algorithm
```
Dstates = { ε-closure({start}) }, unmarked
while there is an unmarked T in Dstates:
    mark T
    for each input symbol c:
        U = ε-closure( move(T, c) )
        if U not already in Dstates: add U unmarked
        Dtran[T, c] = U
A DFA state is FINAL iff its set contains at least one NFA final state.
```

- `ε-closure(S)` = every state reachable from `S` using only ε-edges. Computed as a fixed point:
  keep unioning in the ε-successors of members until the set stops growing.
- `move(S, c)` = the union of all `c`-edges out of the members of `S`.

### Implementation trick
A set of NFA states is stored as a **bitmask** in an `unsigned long long` (bit *i* set ⇔ state *i*
is in the set). Then:
- union is `|`
- membership is `(s >> i) & 1`
- "have I seen this subset before?" is a plain `==` comparison

which is why the whole program is ~120 lines. Limit: 63 NFA states.

```c
SET closure(SET s) {
    SET res = s; int changed = 1;
    while (changed) { changed = 0;
        for (int i = 0; i < n; i++)
            if ((res >> i) & 1ULL) { SET t = res | eps[i]; if (t != res) { res = t; changed = 1; } }
    }
    return res;
}
SET move(SET s, int c) {
    SET r = 0;
    for (int i = 0; i < n; i++) if ((s >> i) & 1ULL) r |= trans[i][c];
    return r;
}
```
The discovery loop is a simple worklist — because new states are appended to `dstate[]` and the
outer `for (i = 0; i < ndfa; i++)` re-reads `ndfa` each iteration, newly found states get
processed automatically.

### Input format
```
n                 number of NFA states (named 0..n-1)
m                 number of input symbols (ε is NOT counted)
s1 ... sm         the symbols
start
f  q1 ... qf      number of final states, then the final states
t                 number of transitions
from sym to       t lines; write 'e' for an ε-move
```

`input/in12.txt` is Thompson's NFA for **(a|b)\*abb** (the Dragon Book example):
```
11
2
a b
0
1
10
13
0 e 1
0 e 7
1 e 2
1 e 4
2 a 3
3 e 6
4 b 5
5 e 6
6 e 1
6 e 7
7 a 8
8 b 9
9 b 10
```

### Output (verified — this program was compiled and run)
```
DFA states (subset construction):
  A = {0,1,2,4,7}
  B = {1,2,3,4,6,7,8}
  C = {1,2,4,5,6,7}
  D = {1,2,4,5,6,7,9}
  E = {1,2,4,5,6,7,10}   <-- FINAL

DFA transition table:
  state |     a |     b |
  ------+-------+-------+
   ->A   |   B   |   C   |
     B   |   B   |   D   |
     C   |   B   |   C   |
     D   |   B   |   E   |
     E   |   B   |   C   |

(start state is marked with ->, '--' means dead state)
```
This is exactly the DFA in the textbook, which is a good correctness check.

---

## Problem 18 — Flex lexer + symbol table integration
**File:** `src/p18_symtab.l` **Input:** `input/in18.c`

### Data structure
A **hash table per scope level**, plus a scope counter:

```c
Sym *table[MAXSCOPE][HSIZE];   /* table[level][bucket] -> linked list */
int cur = 0;                   /* 0 = global */
```
- `{` → `cur++` (enter scope), `}` → dump + free that level, then `cur--`.
- `lookup_current()` searches only `table[cur]` → used to detect **redeclaration**.
- `lookup_all()` walks `cur, cur-1, ..., 0` → **innermost-scope-outward** resolution, so an inner
  `int a` correctly shadows the outer one.
- Hash function `h = h*31 + c`, mod 101 (a prime, to spread buckets).

### The hard part: telling a *declaration* from a *use*
A lexer has no grammar, so you fake a tiny bit of state with two flags:

| Token seen | Effect |
|---|---|
| type keyword (`int`, `float`, …) | `in_decl = 1; expect_name = 1;` remember the type |
| identifier | if `in_decl && expect_name` → **insert**, then `expect_name = 0`; else → **lookup** |
| `,` | if `in_decl`, `expect_name = 1` again (handles `int a, b;`) |
| `=` | `expect_name = 0` (so `int x = y;` treats `y` as a *use*) |
| `;` | `in_decl = 0; expect_name = 0` |
| `{` / `}` | push / pop scope, reset both flags |

Two flags instead of one is what makes `int a, b;` and `int x = y;` both come out right.
This is genuinely a hack — the real fix is to do symbol-table insertion from the **parser**
(which is what Problem 23 does). Say so in your report; it earns marks.

### Input (`input/in18.c`)
```c
int x;
float y;
int x;
void main() {
    int a, b;
    a = x + 1;
    {
        int a;
        a = b;
        c = 5;
    }
    b = a;
}
```

### Output
```
=== scope 0 (global) ===
  INSERT  x          type=int     scope=0  line=1
  INSERT  y          type=float   scope=0  line=2
  ERROR line 3: 'x' redeclared in scope 0 (first declared line 1)
  INSERT  main       type=void    scope=0  line=4
--- entering scope 1
  INSERT  a          type=int     scope=1  line=5
  INSERT  b          type=int     scope=1  line=5
  USE     a          -> type=int     declared in scope 1, line 5
  USE     x          -> type=int     declared in scope 0, line 1
--- entering scope 2
  INSERT  a          type=int     scope=2  line=8
  USE     a          -> type=int     declared in scope 2, line 8
  USE     b          -> type=int     declared in scope 1, line 5
  ERROR line 10: 'c' used but never declared
--- leaving scope 2 | symbols: a:int
  USE     b          -> type=int     declared in scope 1, line 5
  USE     a          -> type=int     declared in scope 1, line 5
--- leaving scope 1 | symbols: a:int  b:int
--- leaving scope 0 | symbols: x:int  y:float  main:void

Total semantic errors: 2
```
The two key lines to point at in a viva: `USE a` inside scope 2 resolves to the **line 8**
declaration (shadowing works), and the same `a` after `}` resolves back to **line 5**.

> Symbols within one scope are printed in hash-bucket order, so their relative order may differ
> on your machine. That's normal for a hash table.

---

## Problem 23 — Bison calculator with variables
**Files:** `src/p23_calc.y`, `src/p23_calc.l` **Input:** `input/in23.txt`

### Anatomy of a `.y` (Bison) file
```
%{  ... C prologue: includes, symbol table, yylex/yyerror decls ...  %}
%union { ... }            /* the C type of semantic values */
%token <num> NUMBER       /* terminals, with which union member they carry */
%type  <num> expr         /* non-terminals, same idea */
%left '+' '-'             /* precedence: later lines bind TIGHTER */
%%
nonterminal : production   { action using $$ , $1 , $2 ... }
            | production   { ... }
            ;
%%
   ... C epilogue: yyerror(), main() ...
```

| Symbol | Meaning |
|---|---|
| `$$` | the value of the left-hand side (what this rule produces) |
| `$1`, `$2`, … | the values of the 1st, 2nd… symbols on the right-hand side |
| `yylval` | how the lexer hands a value to the parser |
| `yyparse()` | runs the parser; it calls `yylex()` whenever it needs a token |
| `bison -d` | also emits `foo.tab.h`, which the lexer `#include`s to learn the token codes |

### Precedence — how `2 + 3 * 4` becomes 14
The grammar `expr : expr '+' expr | expr '*' expr` is **ambiguous**, which normally means
shift/reduce conflicts. Instead of rewriting it into `expr/term/factor`, declare precedence:

```
%left  '+' '-'          /* lowest  */
%left  '*' '/'
%right UMINUS           /* highest */
```
Bison resolves each conflict using these: `*` binds tighter because it is declared **later**,
and `%left` means same-precedence operators group left-to-right (`8-3-2` = 3, not 7).

`UMINUS` is a **fictitious token** — it appears in no rule, it exists only to carry a precedence.
`'-' expr %prec UMINUS` says "give this particular production UMINUS's precedence", which is how
`-x * 2` parses as `(-x) * 2` while binary minus still stays low-precedence.

### Connecting lexer → parser
```c
/* .l */  [0-9]+(\.[0-9]+)?      { yylval.num = atof(yytext); return NUMBER; }
          [A-Za-z_][A-Za-z0-9_]* { yylval.id  = strdup(yytext); return NAME; }
          [-+*/()=;]             { return yytext[0]; }   /* single chars are their own token */
```
`strdup` matters: `yytext` is overwritten by the next token, so the identifier must be copied.
The parser `free()`s it in the action, otherwise you leak one allocation per identifier.

### Symbol table hook
```c
stmt : NAME '=' expr ';'  { setvar($1, $3); printf("%s = %g\n", $1, $3); free($1); }
expr : NAME               { int ok; $$ = getvar($1, &ok);
                            if (!ok) fprintf(stderr, "Line %d: '%s' undefined, using 0\n",
                                             yylineno, $1);
                            free($1); }
```
No conflict arises between `stmt: NAME '=' ...` and `expr: NAME` because one token of lookahead
settles it: if the token after `NAME` is `=`, shift; otherwise reduce `NAME` to `expr`.

### Input (`input/in23.txt`)
```
x = 5;
y = x + 3;
z = (x + y) * 2 - 4;
print z;
w = -x + z / 2;
print w + q;
```

### Output
```
x = 5
y = 8
z = 22
= 22
w = 6
Line 6: warning: 'q' is undefined, using 0
= 6

--- final symbol table ---
  x          = 5
  y          = 8
  z          = 22
  w          = 6
```
Trace `z`: `(5 + 8) * 2 - 4` = `13 * 2 - 4` = `26 - 4` = 22 — precedence is doing its job.
Trace `w`: `-5 + 22/2` = `-5 + 11` = 6 — unary minus bound tighter than `+`.

---

## Problem 24 — Panic-mode error recovery
**Files:** `src/p24_calc.y`, `src/p24_calc.l` **Input:** `input/in24.txt`

### Logic
Without recovery, `yyparse()` calls `yyerror()` once and stops — you find one error per compile.
Panic mode fixes this with **one extra production**:

```
stmt : NAME '=' expr ';'
     | PRINT expr ';'
     | expr ';'
     | error ';'          { yyerrok; printf("   ...recovered, skipped to ';'\n"); }
     ;
```

`error` is a built-in Bison token. When a syntax error is detected the parser:

1. calls `yyerror()` (where you print the message and count it);
2. **pops states off the stack** until it reaches a state where `error` can be shifted — here,
   the start of a `stmt`;
3. shifts `error`, then **discards input tokens** until it finds one it can shift next — here `;`;
4. reduces `stmt : error ';'` and carries on with the next statement.

`;` is the ideal **synchronising token**: it marks the end of a statement, so everything discarded
belongs to the broken statement and nothing good is thrown away. In a full language you'd add
`error '}'` too.

`yyerrok` tells Bison "I've handled it, leave error-suppression mode" — without it, Bison stays
quiet about the next three tokens and can hide a second real error. Errors are counted in
`yyerror()` and reported at the end, so the exit status is meaningful.

Also add `%define parse.error verbose` (older Bison: `%error-verbose`) to upgrade the message
from `syntax error` to `syntax error, unexpected ';', expecting NUMBER or NAME or '(' or '-'`.

### Input (`input/in24.txt`)
```
x = 5;
y = x + ;
z = x * 2;
a = (z + 1;
print z;
b = 3 4;
print b;
```

### Output
```
x = 5
Line 2: syntax error: syntax error, unexpected ';'
   ...recovered, skipped to ';'
z = 10
Line 4: syntax error: syntax error, unexpected ';', expecting ')'
   ...recovered, skipped to ';'
= 10
Line 6: syntax error: syntax error, unexpected NUMBER, expecting ';'
   ...recovered, skipped to ';'
Line 7: semantic warning: 'b' undefined, using 0
= 0

--- final symbol table ---
  x          = 5
  z          = 10

Parsing finished with 3 syntax error(s).
```
The exact wording after "syntax error:" depends on your Bison version; the structure — three
errors reported, parsing continued to the end, good statements still evaluated — is the point.
Notice the knock-on effect on line 7: `b` was never assigned because its statement was discarded,
so the semantic checker reports it as undefined. Errors cascading like that is expected and worth
mentioning in your report.

---

## Quick self-test questions (these get asked in labs)

1. Why does `3.14.5` report an error even though the error rule is written *last*?
   → Longest match beats rule order; only *ties* are broken by order.
2. Why must string literals be handled before whitespace collapsing in Problem 1?
   → Otherwise inner spaces get collapsed and a `//` inside a string starts a comment.
3. What is the difference between `%s` and `%x` start conditions?
   → `%s` is inclusive (rules with no condition still apply); `%x` is exclusive (only rules
   tagged with that condition apply). Use `%x` for comments and strings.
4. Why is `UMINUS` needed?
   → A production's precedence is normally that of its rightmost terminal; `'-' expr` would
   inherit binary minus's low precedence, so `%prec UMINUS` overrides it.
5. What does `yyerrok` do that just writing `error ';'` doesn't?
   → It leaves error-suppression mode immediately, so a second error on the next statement is
   still reported.
6. Why can subset construction blow up?
   → An *n*-state NFA can produce up to 2ⁿ DFA states in the worst case; in practice far fewer,
   because only reachable subsets are generated.
