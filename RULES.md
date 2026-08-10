# RULES.md — Every Rule, Explained Piece by Piece

Every symbol in every rule of every program, in plain words.
The rules below are copied **exactly** from the source files — every backslash, quote, star and
bracket is preserved.

---

# Part 1 — How to read any Flex rule

Every rule line has exactly two halves:

```lex
[0-9]+          { printf("NUMBER\n"); }
└──────┘        └────────────────────┘
 PATTERN               ACTION
"what to look for"   "what to do when you find it"
```

The **pattern** is on the left. The **action** is in `{ }` on the right.

Read every rule as a sentence: *"If you see ⟨pattern⟩, then do ⟨action⟩."*

And the file always has this shape:

```
%{   ... C code: #include, variables, helper functions ...   %}
%%
   rules go here
%%
   main() goes here
```

The `%%` lines are fences. They just say "the rules start here" and "the rules end here".

---

# Part 2 — The decoder ring 🔑

This is the whole language. Learn this table and you can read every rule in the project.

| Symbol | Say it out loud | What it means |
|:---:|---|---|
| `a` | "letter a" | the actual letter a |
| `.` | "dot" | **any one character** — except a newline |
| `*` | "star" | the thing before it, **zero or more** times |
| `+` | "plus" | the thing before it, **one or more** times |
| `?` | "question" | the thing before it, **zero or one** time (optional) |
| `{2,}` | "two or more" | the thing before it, at least 2 times |
| `\|` | "or" | left side **or** right side |
| `( )` | "box" | groups things together into one unit |
| `[ ]` | "pick one" | a **character class** — match any ONE character from inside |
| `[^ ]` | "pick none" | match any one character **except** those inside |
| `[a-z]` | "a through z" | a range — any lowercase letter |
| `-` | "dash" | makes a range **inside** `[ ]`; a plain dash everywhere else |
| `" "` | "quotes" | everything inside is a **plain literal** — no magic |
| `\` | "backslash" | turns off magic, or makes a special character |
| `^` | "hat" | **NOT** when it's first inside `[ ]`; "start of line" outside |
| `$` | "dollar" | end of line |
| `<NAME>` | "in mode NAME" | this rule only applies while the scanner is in that mode |

### Two words you will use constantly

| Name | Meaning |
|---|---|
| `yytext` | the exact text that was just matched |
| `yyleng` | how many characters that text was |

---

# Part 3 — The backslash `\`, properly ⭐

This confuses everyone, so here it is once, clearly.

A backslash always affects **the character right after it**. It does one of two jobs.

### Job 1 — make a special character

| You write | You get |
|:---:|---|
| `\n` | a newline (the Enter key) |
| `\t` | a tab |
| `\r` | a carriage return (the invisible extra character Windows adds) |

### Job 2 — turn off magic

Some characters have powers. A backslash removes the power and leaves the plain character.

| You write | You get | Without the backslash it would mean |
|:---:|---|---|
| `\.` | a real dot `.` | "any character" |
| `\"` | a real double quote `"` | the start of a quoted literal |
| `\\` | **one** real backslash `\` | it would try to escape the next thing |

### The one that trips people: `\\.`

There are **three** characters here: `\` `\` `.`

- The first `\` says "the next character is plain".
- So `\\` together = **one real backslash**.
- Then `.` = **any one character**.

So `\\.` means: **a backslash, followed by any one character.**

That is exactly what an escape sequence looks like inside a string:

```
\n     backslash + n     ✓ matches
\t     backslash + t     ✓ matches
\"     backslash + "     ✓ matches
```

That last one is the important one — it's how `"He said \"hi\""` stays in one piece instead of
ending early at the middle quote.

### Quotes vs backslash — two ways to say "plain"

```lex
"int"     ← quotes:    everything inside is plain
\.        ← backslash: just this one character is plain
```

Both are correct. `"+"` and `\+` mean the same thing. Use quotes for words, backslashes for
single symbols.

---

# Part 4 — Problem 1: Whitespace & Comment Stripper

```lex
"/*"                { BEGIN(COMMENT); }
<COMMENT>"*/"       { BEGIN(INITIAL); }
<COMMENT>.|\n       { /* Ignore multi-line comments */ }
"//".*              { /* Ignore single-line comments */ }
[ \t\r\n]+          { printf(" "); }
.                   { printf("%s", yytext); }
```

### The big idea: modes 🎭

This program has a **blindfold mode**. Normally the scanner copies what it sees. When it spots
`/*` it puts a blindfold on and throws everything away until it sees `*/`.

The mode is declared above the rules with `%x COMMENT`. The `x` means *exclusive* — while the
blindfold is on, **only** rules marked `<COMMENT>` are allowed to run.

### Rule 1 — `"/*"`

| Piece | Means |
|:---:|---|
| `"` `"` | quotes: everything inside is plain, no magic |
| `/*` | the two characters slash and star |

**Sentence:** if you see `/*`, run `BEGIN(COMMENT)` — put the blindfold on.

> Why quotes? Because `*` normally means "zero or more". Inside quotes it loses that power and
> becomes an ordinary star.

### Rule 2 — `<COMMENT>"*/"`

| Piece | Means |
|:---:|---|
| `<COMMENT>` | this rule only works while the blindfold is on |
| `"*/"` | the plain characters star and slash |

**Sentence:** while blindfolded, if you see `*/`, run `BEGIN(INITIAL)` — take the blindfold off.
`INITIAL` is the built-in name for normal mode.

### Rule 3 — `<COMMENT>.|\n`

| Piece | Means |
|:---:|---|
| `<COMMENT>` | only while blindfolded |
| `.` | any one character |
| `\|` | or |
| `\n` | a newline |

**Sentence:** while blindfolded, eat any character, including newlines, and do nothing with it.

> Why is `\n` needed separately? Because `.` deliberately does **not** match newlines. Without
> `\n` here, the scanner would get stuck at the end of each line inside a comment.

### Rule 4 — `"//".*`

| Piece | Means |
|:---:|---|
| `"//"` | the two plain characters |
| `.` | any character |
| `*` | zero or more of them |

**Sentence:** `//` followed by anything, right to the end of the line.

> This one needs no mode. Since `.` stops at newlines, `.*` automatically stops at the end of
> the line — which is exactly where a `//` comment ends. 🎯

### Rule 5 — `[ \t\r\n]+`

| Piece | Means |
|:---:|---|
| `[` | start of "pick one" list |
| (space) | a space — yes, a real space is a character in the list |
| `\t` | tab |
| `\r` | carriage return |
| `\n` | newline |
| `]` | end of list |
| `+` | one or more of them |

**Sentence:** a whole run of blank space of any kind. Print exactly one space instead.

> This is the "collapsing". Twenty spaces are grabbed as **one** match because of the `+`, and
> one space is printed.

### Rule 6 — `.`

**Sentence:** any other single character — print it unchanged. This is the catch-all, and it
must always be last, because a catch-all placed early would eat everything.

---

# Part 5 — Problem 3: Identifier & Keyword Classifier

```lex
"int"|"float"|"char"|"if"|"else"|"while"|"for"|"return" { printf("KEYWORD: %s\n", yytext); }
[a-zA-Z_][a-zA-Z0-9_]*                                  { printf("IDENTIFIER: %s\n", yytext); }
[0-9]+(\.[0-9]+)?                                       { printf("NUMBER: %s\n", yytext); }
"=="|"!="|"<="|">="|"&&"|"||"|"++"|"--"|"+"|"-"|"*"|"/"|"="|"<"|">" { printf("OPERATOR: %s\n", yytext); }
";"|","|"("|")"|"{"|"}"|"["|"]"                         { printf("PUNCTUATION: %s\n", yytext); }
[ \t\n\r]+                                              { /* Ignore whitespace */ }
.                                                       { printf("UNKNOWN: %s\n", yytext); }
```

### Rule 1 — the keyword list

`"int"|"float"|"char"|...` is just **word OR word OR word**. Each word is in quotes so it stays
plain, and `|` separates them.

**Why is it first?** Because `int` also fits the identifier pattern below. Both would match 3
characters — a tie — and Flex breaks ties by taking the rule written **higher up**. Move this
rule below the identifier rule and every keyword would be misreported. ⚠️

### Rule 2 — `[a-zA-Z_][a-zA-Z0-9_]*`

There are **two** boxes here, side by side. Side by side means "first this, then that".

| Piece | Means |
|:---:|---|
| `[a-zA-Z_]` | **one** character: a lowercase letter, an uppercase letter, or underscore |
| `[a-zA-Z0-9_]` | one character: letter, digit, or underscore |
| `*` | zero or more of those |

**Sentence:** a name starts with a letter or underscore, then has any number of letters, digits
or underscores.

> This is exactly the C rule for names — it's why `count2` is legal but `2count` is not.

### Rule 3 — `[0-9]+(\.[0-9]+)?`

| Piece | Means |
|:---:|---|
| `[0-9]` | one digit |
| `+` | one or more digits |
| `(` `)` | a box holding the decimal part |
| `\.` | a **real dot** — the backslash removes "any character" |
| `[0-9]+` | one or more digits after the dot |
| `?` | the whole box is optional |

**Sentence:** some digits, then *optionally* a dot with more digits after it.

So `42` ✓ and `3.14` ✓, but `3.` ✗ (the box demands digits after the dot) and `.5` ✗ (it demands
digits before it).

### Rule 4 — the operator list

Same shape as the keyword list. The important detail is that the **two-character operators come
first**: `"=="` before `"="`.

> Actually Flex would get this right anyway, because `==` is a longer match than `=`. Writing it
> in this order is just a good habit — it makes your intention obvious to whoever reads it.

### Rule 5 — punctuation, Rule 6 — whitespace, Rule 7 — catch-all

Same as Problem 1. Note the catch-all here **prints** `UNKNOWN` instead of ignoring, which is how
a character like `#` gets reported.

---

# Part 6 — Problem 5: Number Classifier

```lex
[0-9]+\.[0-9]+([eE][+-]?[0-9]+)? { printf("FLOAT: %s\n", yytext); }
[0-9]+[eE][+-]?[0-9]+            { printf("SCIENTIFIC: %s\n", yytext); }
[0-9]+                           { printf("INTEGER: %s\n", yytext); }
[0-9]+\.[0-9]*\.[0-9.]*          { printf("INVALID NUMBER FORMAT: %s\n", yytext); }
[0-9]+[a-zA-Z_][a-zA-Z0-9_]*     { printf("INVALID NUMBER FORMAT: %s\n", yytext); }
[ \t\n\r]+                       { /* Ignore whitespace */ }
.                                { /* Ignore others */ }
```

### Rule 1 — `[0-9]+\.[0-9]+([eE][+-]?[0-9]+)?`

Read it in three chunks:

```
[0-9]+        \.        [0-9]+        ([eE][+-]?[0-9]+)?
digits    real dot    more digits      optional exponent
   3          .            14              e-2
```

The exponent box, opened up:

| Piece | Means |
|:---:|---|
| `[eE]` | the letter e, either case |
| `[+-]` | a plus or a minus |
| `?` | ...but that sign is optional |
| `[0-9]+` | **at least one digit** — this is what makes `1e` illegal |
| `?` (outer) | the entire exponent is optional |

**Sentence:** digits, dot, digits, and optionally `e` with a signed number.

> Note `[+-]`: the dash is **last** in the list, so it's a plain dash and not a range. A dash is
> only a range when it sits *between* two characters, like `a-z`.

### Rule 2 — `[0-9]+[eE][+-]?[0-9]+`

The same exponent, but with **no dot at all**. This is `10E5`.

### Rule 3 — `[0-9]+`

Plain digits. An integer.

### Rule 4 — `[0-9]+\.[0-9]*\.[0-9.]*` — the broken one

| Piece | Means |
|:---:|---|
| `[0-9]+` | digits |
| `\.` | a real dot |
| `[0-9]*` | digits (possibly none) |
| `\.` | **a second real dot** ← the crime 🚨 |
| `[0-9.]*` | digits and dots, any amount |

Look inside that last class: `[0-9.]`. The dot is **inside brackets**, and inside a `[ ]` list a
dot is always just a plain dot — it needs no backslash there. Handy to know.

**Why does this win over the FLOAT rule?** For `3.14.15`:

```
FLOAT rule reaches:    3.14        →  4 characters
this rule reaches:     3.14.15     →  7 characters
```

Flex always takes the **longest** match, so the error rule wins even though it is written last.
That is the whole trick of this problem. 🎯

### Rule 5 — `[0-9]+[a-zA-Z_][a-zA-Z0-9_]*`

Digits, then a letter, then more name characters. That's `12abc`. Same longest-match trick: the
INTEGER rule reaches only `12`, this reaches all 5.

---

# Part 7 — Problem 6: String & Character Literals

```lex
\"([^"\n]|\\.)*\" { printf("STRING LITERAL: %s\n", yytext); }
'([^'\n]|\\.)+'   { printf("CHARACTER LITERAL: %s\n", yytext); }
\"([^"\n]|\\.)*   { printf("LEXICAL ERROR: Unterminated string %s\n", yytext); }
'([^'\n]|\\.)*    { printf("LEXICAL ERROR: Unterminated char %s\n", yytext); }
[ \t\n\r]+        { /* Ignore whitespace */ }
.                 { /* Ignore others */ }
```

### Rule 1 — `\"([^"\n]|\\.)*\"`, piece by piece

| # | Piece | Means |
|:---:|:---:|---|
| 1 | `\"` | a real double quote — the **opening** one |
| 2 | `(` | open a box |
| 3 | `[^"\n]` | any one character that is **not** a quote and **not** a newline |
| 4 | `\|` | or |
| 5 | `\\.` | a backslash followed by any one character (an escape) |
| 6 | `)` | close the box |
| 7 | `*` | repeat the box zero or more times |
| 8 | `\"` | a real double quote — the **closing** one |

**Sentence:** *a quote → then any number of (ordinary characters or escapes) → then a quote.*

### The two clever bits

**Why `[^"\n]` excludes the quote:** so the middle of the string can't swallow the closing quote
and keep going forever.

**Why `\\.` is needed anyway:** because of `\"`. In `"He said \"hi\""`, that middle `\"` **is** a
quote — but it's escaped, so it shouldn't end the string. The `\\.` alternative grabs the
backslash *and* the quote together as one unit, so the quote never gets seen on its own. 🎯

**Why `\n` is excluded:** so a broken string stops at the end of its line instead of eating the
rest of your file.

### Rule 2 — `'([^'\n]|\\.)+'`

Identical shape, with three changes:

| String rule | Char rule | Why |
|:---:|:---:|---|
| `\"` | `'` | single quote instead of double. A single quote has no special power in Flex, so it needs no backslash |
| `[^"\n]` | `[^'\n]` | now it's the single quote that must be excluded |
| `*` | `+` | `*` = zero or more, `+` = **one or more** — a character literal must contain something, so `''` is not accepted |

### Rules 3 and 4 — the unterminated versions

Put them side by side and the difference is one thing:

```
GOOD:   \"([^"\n]|\\.)*\"
BAD:    \"([^"\n]|\\.)*
                        ↑
              no closing quote
```

**So why doesn't the BAD rule fire on a good string too?** It *can* match — but only up to the
last character before the closing quote, which is **shorter**. The good rule includes the closing
quote, so it's longer, so it wins.

```
Input:  "Hello"
GOOD rule grabs:  "Hello"   → 7 characters  ✓ winner
BAD  rule grabs:  "Hello    → 6 characters
```

And when there is no closing quote, the good rule can't match at all, so the bad rule fires and
prints the error. The two rules automatically hand over to each other. 🎯

---

# Part 8 — Problem 7: Regex Pattern Recognizer

```lex
abb        { printf("Matches Pattern 4 (abb): %s\n", yytext); }
(ab)+      { printf("Matches Pattern 3 ((ab)*): %s\n", yytext); }
a*b+       { printf("Matches Pattern 2 (a*b+): %s\n", yytext); }
a+         { printf("Matches Pattern 1 (a*): %s\n", yytext); }
[ \t\n\r]+ { /* Ignore whitespace */ }
.          { printf("Unrecognized: %s\n", yytext); }
```

### The four patterns

| Pattern | Means | Examples |
|:---:|---|---|
| `abb` | exactly those three letters | `abb` |
| `(ab)+` | the **pair** `ab`, repeated one or more times | `ab`, `abab`, `ababab` |
| `a*b+` | any number of a's, then at least one b | `b`, `ab`, `aab`, `bb` |
| `a+` | one or more a's | `a`, `aaa` |

Notice where the box matters:

```
(ab)+   →  ab ab ab      the box repeats  ✓
ab+     →  a b b b       only the b repeats  ✗ different thing!
```

`+` and `*` only apply to the **one thing** immediately before them. Use `( )` when you want them
to apply to a group.

### Why this exact order matters ⚠️

The four languages **overlap** — one string can belong to several:

| String | Belongs to | Reported as |
|:---:|---|---|
| `abb` | `abb` and `a*b+` | Pattern 4, because `abb` is written first |
| `ab` | `(ab)+` and `a*b+` | Pattern 3, because `(ab)+` is written first |

Every one of those pairs matches the **same number of characters**, so it's a tie every time, and
ties are settled by rule order. Rewrite the rules in a different order and you get different
labels. That is the entire lesson of this problem.

### Why `a+` and not `a*` ⚠️

`a*` means "zero or more a's" — which includes **zero**. A pattern that can match zero characters
would let Flex match nothing, move forward zero steps, and match nothing again... forever. 🔁

So the empty case is excluded from the code and explained in the report instead.

---

# Part 9 — Problem 8: Operator Validator

```lex
"<<="|">>=" { printf("VALID OPERATOR: %s\n", yytext); }
"++"|"--"|"=="|"!="|"<="|">="|"&&"|"||"|"+="|"-="|"*="|"/="|"%="|"<<"|">>"|"->" {
    printf("VALID OPERATOR: %s\n", yytext);
}
"+"|"-"|"*"|"/"|"="|"<"|">"|"!"|"%" { printf("VALID OPERATOR: %s\n", yytext); }
[-+*/=<>!&|%]{2,}                   { printf("MALFORMED OPERATOR ERROR: %s\n", yytext); }
[ \t\n\r]+ { /* Ignore whitespace */ }
.          { /* Ignore others */ }
```

### Rules 1–3 — the good list

Nothing new: quoted operators separated by `|`, longest ones written first (3 characters, then 2,
then 1). Every operator is in quotes so `*`, `+`, `|` lose their magic and become plain symbols.

### Rule 4 — `[-+*/=<>!&|%]{2,}` — the trap 🪤

| Piece | Means |
|:---:|---|
| `[` | start of "pick one" list |
| `-` | a plain dash — it's **first**, so it can't form a range |
| `+ * / = < > ! & \| %` | the other operator characters, all plain inside `[ ]` |
| `]` | end of list |
| `{2,}` | two or more of them in a row |

**Sentence:** two or more operator characters stuck together.

### Why one rule catches every possible mistake

You never list the bad operators. You list the good ones, then say "any pile of two-or-more
operator characters is suspicious", and the two Flex habits sort it out:

| Input | Good rule grabs | Trap grabs | Winner | Because |
|:---:|:---:|:---:|---|---|
| `++` | 2 | 2 | ✅ VALID | tie → higher rule wins |
| `+=` | 2 | 2 | ✅ VALID | tie → higher rule wins |
| `=+` | 1 (`=`) | 2 | ❌ ERROR | longer wins |
| `+*` | 1 (`+`) | 2 | ❌ ERROR | longer wins |
| `===` | 2 (`==`) | 3 | ❌ ERROR | longer wins |

Good operators always tie with the trap, so they escape it by being listed first. Bad ones are
always longer than any good match, so the trap catches them. 🎯

---

# Part 10 — Problem 18: Symbol Table + Lexer

```lex
"int"|"float"|"char"|"double"|"void" { is_decl = 1; want_id = 1; strcpy(cur_type, yytext); }
"if"|"else"|"while"|"for"|"return"   { is_decl = 0; want_id = 0; }
[a-zA-Z_][a-zA-Z0-9_]* {
        if (is_decl && want_id) { insert(yytext); want_id = 0; }
        else lookup(yytext);
    }
"{"  { cur_scope++; printf("--- entering scope %d\n", cur_scope); is_decl = 0; want_id = 0; }
"}"  { close_scope(); is_decl = 0; want_id = 0; }
","  { if (is_decl) want_id = 1; }
"="  { want_id = 0; }
";"  { is_decl = 0; want_id = 0; }
"//".*      { /* ignore comment */ }
[0-9]+      { /* ignore numbers */ }
\n          { line_no++; }
[ \t\r]+    { /* ignore whitespace */ }
.           { /* ignore other symbols */ }
```

Every **pattern** here you already know. What's new is that the **actions** do real work instead
of just printing.

### The problem being solved

Look at these two lines:

```c
int x;      ←  x is being CREATED   (a declaration)
x = 5;      ←  x is being USED      (a use)
```

The identifier `x` looks identical to the scanner both times. A lexer has no grammar, so it can't
tell them apart on its own. Two switches solve it:

| Switch | Question it answers |
|:---:|---|
| `is_decl` | are we inside a declaration statement right now? |
| `want_id` | is the very next name the one being created? |

### Following the switches through `int a, b;`

| Sees | Switches after | What happens |
|:---:|:---:|---|
| `int` | `is_decl=1`, `want_id=1` | a declaration is starting; remember the type |
| `a` | `want_id=0` | both switches were on → **insert a** |
| `,` | `want_id=1` | still in a declaration, so another name is coming |
| `b` | `want_id=0` | both on again → **insert b** |
| `;` | both `0` | the declaration is over |

And through `int x = y;`:

| Sees | Switches after | What happens |
|:---:|:---:|---|
| `int` | `1`, `1` | declaration starting |
| `x` | `want_id=0` | **insert x** |
| `=` | `want_id=0` | (already off — this is here for safety) |
| `y` | — | `want_id` is off → **look up y** ✓ correct |

### Why the comma rule says `if (is_decl)`

Commas appear outside declarations too, like in `f(a, b)`. Without the guard, that comma would
switch `want_id` back on and the scanner would wrongly try to *create* `b`. The guard makes the
comma only work while a declaration is genuinely in progress. 🎯

### The `{` and `}` rules — scope

Think of scopes as nested boxes. `{` opens a box, `}` closes it and everything declared inside is
thrown away. That's why an `a` declared inside an inner `{ }` disappears when the block ends and
the outer `a` becomes visible again.

### `\n { line_no++; }`

The scanner counts lines itself so error messages can say *which* line. This rule is the only
reason `ERROR line 10` knows it's line 10.

---

# Part 11 — Problems 23 & 24: the Bison files

The **lexer** (`p23.l`) is short, and its patterns are all familiar:

```lex
[0-9]+(\.[0-9]+)?        { yylval.num = atof(yytext); return NUMBER; }
[a-zA-Z_][a-zA-Z0-9_]*   { yylval.id  = strdup(yytext); return NAME; }
[-+*/()=;]               { return yytext[0]; }
[ \t\r\n]+               { /* Ignore whitespace */ }
.                        { printf("Illegal character: %s\n", yytext); }
```

### What's different: the actions now `return`

In every earlier program the lexer **printed**. Here it **returns**, because it now has a boss —
the parser. The lexer is a waiter taking one order at a time back to the kitchen.

| Piece | Means |
|:---:|---|
| `return NUMBER;` | tell the parser "I found a number" |
| `yylval.num = atof(yytext);` | ...and here is its **value**, converted from text to a number |
| `strdup(yytext)` | make a **copy** of the name — `yytext` gets overwritten by the next token, so a copy is essential |
| `return yytext[0];` | for single symbols like `+`, just send the character itself |
| `[-+*/()=;]` | dash **first** again, so it's a plain dash and not a range |

### The parser's decoder ring

| Symbol | Means |
|:---:|---|
| `%union { double num; char *id; }` | tokens carry values, and there are two kinds: numbers and names |
| `%token <num> NUMBER` | NUMBER is a token, and it carries the `num` kind |
| `%type <num> expr` | `expr` isn't a token, it's built from other things — and it produces a `num` |
| `%left '+' '-'` | these group left-to-right, and this is the **lowest** precedence line |
| `%left '*' '/'` | declared **later** = binds **tighter** |
| `$$` | the value this rule produces |
| `$1`, `$2`, `$3` | the values of the 1st, 2nd, 3rd things on the right side |
| `\|` | separates alternative ways to build the same thing |

### Reading a grammar rule

```yacc
expr : expr '+' expr      { $$ = $1 + $3; }
       └─1─┘ └2┘ └─3─┘
```

Read it as: *"an expression can be an expression, a plus sign, and another expression — and its
value is the first value plus the third value."*

`$2` is skipped because nobody needs the value of a plus sign. 🙂

### Why `%left '*' '/'` comes second

That single line is what makes `5 + 8 * 2` equal 21 and not 26. **Later line = tighter grip.**
`*` grabs its neighbours before `+` gets a chance, so the multiplication happens first.

And `%left` means equal-strength operators go left-to-right, so `8 - 3 - 2` is `(8-3)-2 = 3`,
not `8-(3-2) = 7`.

### Problem 24's extra line

```yacc
     | error ';'          { yyerrok; printf("   ...recovered, skipped to ';'\n"); }
```

| Piece | Means |
|:---:|---|
| `error` | a **built-in** Bison word — you never declare it. It stands for "something went wrong here" |
| `';'` | the semicolon to run to after something goes wrong |
| `yyerrok` | "I've dealt with it — go back to normal and keep reporting errors" |

**In plain words:** *"If a statement breaks, throw away everything until the next semicolon and
carry on from there."*

The semicolon is the perfect place to restart because it marks the end of a statement, so
everything thrown away belonged to the broken statement. Without this line the parser reports one
error and quits. With it, you see every error in the file. 🎯

---

# Part 12 — Problem 12: no rules, just three ideas

This one is plain C, so there are no patterns to decode. Three functions do all the work:

| Function | In plain words |
|---|---|
| `closure(set)` | "who else can I reach **for free**?" — keeps adding states reachable by free (epsilon) moves until nothing new appears |
| `move(set, c)` | "if I'm standing on all these states and I read the letter `c`, where can I end up?" |
| `addState(set)` | "have I seen this exact group of states before? If yes reuse it, if no give it a new name" |

The whole algorithm is: start with a group, ask where each letter takes you, name each new group
you discover, repeat until nothing new turns up. A group is **final** if any state inside it was
final in the NFA.

---

# Part 13 — The two golden rules (memorise these) 🏆

Almost every trick in this project comes from these two sentences:

> ### 1. Flex always takes the LONGEST match.
> ### 2. If two rules match the same length, the one written FIRST wins.

| Problem | Which rule it uses |
|---|---|
| 3 — keywords before identifiers | rule 2 (tie → first wins) |
| 5 — error patterns win on `3.14.5` | rule 1 (longer wins) |
| 6 — good string beats unterminated | rule 1 (the closing quote makes it longer) |
| 7 — overlapping patterns | rule 2 (every match is the same length) |
| 8 — `+*` caught, `++` allowed | **both** — see the table in Part 9 |

---

# Part 14 — Exam quick-answers

**Q: What does `\\.` mean and why is it needed?**
A backslash followed by any one character. It keeps escape sequences like `\"` in one piece, so
an escaped quote doesn't accidentally end the string.

**Q: Why exclude `\n` inside `[^"\n]`?**
So an unterminated string stops at the end of its line instead of swallowing the rest of the file.

**Q: Why write `a+` instead of `a*`?**
`a*` can match zero characters. Flex would consume nothing and loop forever.

**Q: What's the difference between `%s` and `%x`?**
`%s` is inclusive — unlabelled rules still work in that mode. `%x` is exclusive — only rules
labelled with that mode work. Use `%x` for comments and strings.

**Q: Why does `(ab)+` differ from `ab+`?**
`( )` decides what the `+` repeats. `(ab)+` repeats the pair; `ab+` repeats only the `b`.

**Q: What does `yyerrok` do?**
Tells Bison the error has been handled, so it stops suppressing messages and will report the next
error properly.

**Q: What's `yytext`?**
The exact text that was just matched. `yyleng` is its length.
