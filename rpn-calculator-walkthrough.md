# RPN Stack-Based Calculator — Code Walkthrough

Source: [github.com/nahian242/rpn](https://github.com/nahian242/rpn) — a single Flex file (`main.l`), no Bison/Yacc involved. CSE314 Compiler Design Lab project.

---

## 1. What this project actually is

Most "calculator" compiler-lab projects are two files: a **lexer** (`.l`) that produces tokens, and a **parser** (`.y`) that applies grammar rules (precedence, associativity, parentheses) to those tokens. This project skips the parser entirely — `main.l` is the whole program.

That's possible because the input is **Reverse Polish Notation (RPN)**, also called postfix notation: operators come *after* their operands.

- Infix: `3 + 4 * 2` — needs precedence rules to know `*` binds tighter than `+`.
- Postfix: `3 4 2 * +` — no ambiguity possible. You just read left to right and apply a simple rule: *numbers get pushed onto a stack, operators pop their operands off the stack and push the result back.*

Because postfix removes the need for precedence and parentheses, a stack plus a single left-to-right scan is a complete evaluator. That's the whole reason a **lexer alone** is enough here — there's nothing for a parser to disambiguate. This is a nice teaching example of *when* you need a grammar and *when* you don't.

## 2. Build & run

```bash
flex main.l          # generates lex.yy.c
gcc lex.yy.c -o app   # compiles it into an executable
```

- `./app` — interactive mode, type expressions, `Ctrl+D` to quit
- `./app input.txt` — reads expressions from a file instead of stdin

## 3. Anatomy of the `.l` file

Every Flex file has three sections separated by `%%`:

```
%{  C declarations / helper functions  %}
    Flex definitions (regex shorthands)
%%
    Rules: pattern { action }
%%
    User C code (here: main())
```

The regex shorthands defined near the top:

```c
DIGIT [0-9]
IDENT [a-zA-Z_][a-zA-Z0-9_]*
NUMBER {DIGIT}+(\.{DIGIT}+)?
```

`IDENT` = a variable name (letter/underscore, then letters/digits/underscores). `NUMBER` = an integer or decimal.

## 4. The runtime state (global variables)

Everything the program "remembers" lives in a handful of static globals — this *is* the interpreter's memory:

| Variable | Purpose |
|---|---|
| `stack_arr[100]`, `top` | the operand stack (array-based, `top` = index of top element, `-1` = empty) |
| `symtab[100]` (`Var{name,value}`), `nvars` | the symbol table — every assigned variable |
| `assigning`, `pending_name` | tracks "am I in the middle of an `x = ...` assignment, and what's the variable name" |
| `line_no` | just for error messages |

## 5. The helper functions (the "operations" of the machine)

```c
static void push(double v) {
    if (top >= STACK_SIZE - 1) { fprintf(stderr, "Error: stack overflow\n"); return; }
    stack_arr[++top] = v;
}
static double pop_val(void) {
    if (top < 0) { fprintf(stderr, "Error: stack underflow (missing operand)\n"); return 0.0; }
    return stack_arr[top--];
}
```

Standard array-stack push/pop, each guarded against overflow/underflow so a malformed expression can't crash the program or read garbage memory.

```c
static double lookup(const char *name) { /* linear search symtab[] */ }
static void set_var(const char *name, double value) { /* find-or-append in symtab[] */ }
```

The symbol table is a flat array searched linearly (`strcmp` in a loop) — fine for a lab project with `MAX_VARS = 100`, but O(n) per lookup. A hash table would be the "real" version.

```c
static void binop(char op) {
    double b = pop_val();   // pop order matters!
    double a = pop_val();
    switch (op) {
        case '+': result = a + b; break;
        case '-': result = a - b; break;   // a - b, not b - a
        case '*': result = a * b; break;
        case '/':
            if (b == 0.0) { fprintf(stderr, "Error: division by zero\n"); push(0.0); return; }
            result = a / b;
            break;
    }
    push(result);
}
```

**Order matters here**: the operand pushed *second* is popped *first*. For `3 4 -`, `b=4` is popped first, `a=3` second, giving `a - b = -1`. This mirrors how postfix is meant to be read — the operator applies to the two values immediately preceding it, in the order they appeared.

## 6. The rules — what happens per token

```c
{IDENT}[ \t]*"=" {
    /* matches something like "x =" as ONE token */
    sscanf(yytext, "%63[a-zA-Z0-9_]", name);
    strncpy(pending_name, name, ...);
    assigning = 1;
}
{NUMBER} { push(atof(yytext)); }
{IDENT}  { push(lookup(yytext)); }
"+" { binop('+'); }   "-" { binop('-'); }
"*" { binop('*'); }   "/" { binop('/'); }
```

- The **assignment rule** is matched greedily *before* the plain `IDENT` rule (Flex prefers the longest match, and this pattern is longer), so `x =` never gets tokenized as a bare variable read — it flips `assigning` on and remembers the name.
- A bare `NUMBER` is pushed straight onto the stack.
- A bare `IDENT` (not followed by `=`) is treated as a *read*: look up its stored value and push that.
- Each operator pops two values, computes, pushes the result.

The `\n` rule is where the real decision-making happens — it's essentially the "end of statement" handler:

```c
\n {
    if (assigning) {
        double v = pop_val();
        if (top > -1) fprintf(stderr, "Warning...extra operand(s) left before assignment\n");
        set_var(pending_name, v);
        assigning = 0;
    } else if (top == 0) {
        printf("= %g\n", peek_val());
    } else if (top > 0) {
        fprintf(stderr, "Warning...%d operand(s) left over\n", top + 1);
    }
    top = -1;       // stack resets every line
    line_no++;
}
```

So each line is evaluated independently: if you were assigning, take whatever's on top of the stack as the value to store. Otherwise, if exactly one value remains, that's your answer — print it. Anything else (0 values, or more than 1) means the expression was malformed, so it warns instead of guessing.

Two catch-all rules finish the job: whitespace (`[ \t\r]+`) is silently skipped, and any other character falls into the error rule, which reports it and moves on rather than crashing.

## 7. Tracing an example: `3 4 2 * +`

| Token | Action | Stack after |
|---|---|---|
| `3` | push 3 | `[3]` |
| `4` | push 4 | `[3, 4]` |
| `2` | push 2 | `[3, 4, 2]` |
| `*` | pop 2, pop 4 → `4*2=8`, push 8 | `[3, 8]` |
| `+` | pop 8, pop 3 → `3+8=11`, push 11 | `[11]` |
| `\n` | `top == 0` → print `= 11` | `[]` (reset) |

## 8. Tracing an assignment: `x = 3 4 +` then `x 2 *`

**Line 1: `x = 3 4 +`**

| Token | Action | Stack | `assigning` |
|---|---|---|---|
| `x =` | matched as one token; `pending_name = "x"` | `[]` | `1` |
| `3` | push 3 | `[3]` | `1` |
| `4` | push 4 | `[3, 4]` | `1` |
| `+` | pop 4, pop 3 → 7, push | `[7]` | `1` |
| `\n` | `assigning` true → pop 7, `set_var("x", 7)` | `[]` reset | `0` |

No output is printed — assignment lines are silent by design.

**Line 2: `x 2 *`**

| Token | Action | Stack |
|---|---|---|
| `x` | not followed by `=` → `lookup("x")` = 7, push | `[7]` |
| `2` | push 2 | `[7, 2]` |
| `*` | pop 2, pop 7 → `7*2=14`, push | `[14]` |
| `\n` | `top == 0` → print `= 14` | `[]` |

## 9. `main()` — how input is chosen

```c
int main(int argc, char **argv) {
    if (argc > 1) {
        yyin = fopen(argv[1], "r");   // read from file
    } else {
        printf("RPN Calculator...\n"); // interactive banner
    }
    yylex();
    return 0;
}
```

`yyin` is a Flex-provided global — pointing it at a file makes the generated lexer read from that file instead of `stdin`. Everything else (the whole calculator) is driven purely by the pattern-matching loop inside `yylex()`.

## 10. Error handling, summarized

| Problem | Where caught | Behavior |
|---|---|---|
| Too many `push`es | `push()` | stack overflow error, value dropped |
| Popping an empty stack | `pop_val()` / `peek_val()` | underflow error, returns `0.0` |
| Divide by zero | `binop()` | error, pushes `0.0` instead of crashing |
| Unknown variable read | `lookup()` | error, returns `0.0` |
| Symbol table full | `set_var()` | error, assignment ignored |
| Leftover operands at end of line | `\n` rule | warning, not a hard error |
| Unrecognized character | catch-all `.` rule | error, character skipped, keeps scanning |

Everything degrades gracefully — a bad line prints a warning/error to `stderr` and the program keeps running for the next line, rather than aborting.

## 11. Design notes worth remembering for the lab

- **No grammar file at all.** This is the cleanest illustration of "you don't need Bison/Yacc when the language has no ambiguity" — postfix removes precedence and associativity as concerns entirely.
- **Fixed-size arrays**, no dynamic growth (`STACK_SIZE`, `MAX_VARS` are hard caps) — typical of a teaching-scale project, not production code.
- **No unary minus.** `-` is only ever treated as the binary operator inside `binop()`, so there's no way to write a literal negative number directly (you'd need e.g. `0 5 -` to get `-5`).
- **No parentheses support** — and none are needed, which is itself the point of postfix notation.
- **State lifetime differs by kind:** the *operand stack* resets every line (`top = -1` in the `\n` rule), but the *symbol table* persists for the entire run — that's what lets `x` from line 1 be read back on line 2.

## 12. Ideas to extend it (good practice exercises)

- Add unary minus / a `neg` operator.
- Add more operators: `%` (modulo), `^` (power).
- Swap the linear-search symbol table for a hash table and compare lookup cost.
- Rewrite it *with* Bison, keeping the operand stack, but letting the grammar handle statement structure — useful contrast for seeing what a parser buys you once the language does get more complex (e.g. adding infix support).
- Add a `REPL` command like `vars` to dump the current symbol table.
