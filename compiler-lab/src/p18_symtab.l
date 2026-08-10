/* Problem 18: Flex lexer integrated with a scoped symbol table.
   Build: flex p18_symtab.l && gcc lex.yy.c -o p18 && ./p18 ../input/in18.c   */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define HSIZE     101
#define MAXSCOPE  32

typedef struct Sym {
    char name[64];
    char type[24];
    int  scope, line;
    struct Sym *next;
} Sym;

Sym *table[MAXSCOPE][HSIZE];     /* one hash table per scope level */
int  cur = 0;                    /* current scope level, 0 = global */
int  line = 1, errors = 0;

int  in_decl = 0;                /* are we inside a declaration statement? */
int  expect_name = 0;            /* is the next identifier a declarator?   */
char curtype[24] = "";

static unsigned hash(const char *s) {
    unsigned h = 0;
    while (*s) h = h * 31u + (unsigned char)*s++;
    return h % HSIZE;
}

static Sym *lookup_current(const char *name) {
    Sym *p;
    for (p = table[cur][hash(name)]; p; p = p->next)
        if (strcmp(p->name, name) == 0) return p;
    return NULL;
}

static Sym *lookup_all(const char *name, int *lvl) {   /* innermost scope outward */
    int s; Sym *p;
    for (s = cur; s >= 0; s--)
        for (p = table[s][hash(name)]; p; p = p->next)
            if (strcmp(p->name, name) == 0) { if (lvl) *lvl = s; return p; }
    return NULL;
}

static void insert(const char *name, const char *type, int ln) {
    Sym *old = lookup_current(name), *p;
    unsigned h;
    if (old) {
        printf("  ERROR line %d: '%s' redeclared in scope %d (first declared line %d)\n",
               ln, name, cur, old->line);
        errors++;
        return;
    }
    p = (Sym *)malloc(sizeof(Sym));
    strncpy(p->name, name, 63); p->name[63] = 0;
    strncpy(p->type, type, 23); p->type[23] = 0;
    p->scope = cur; p->line = ln;
    h = hash(name);
    p->next = table[cur][h];
    table[cur][h] = p;
    printf("  INSERT  %-10s type=%-7s scope=%d  line=%d\n", name, type, cur, ln);
}

static void dump_scope(void) {
    int i, any = 0; Sym *p, *nx;
    printf("--- leaving scope %d | symbols: ", cur);
    for (i = 0; i < HSIZE; i++) {
        for (p = table[cur][i]; p; p = nx) { nx = p->next; printf("%s:%s  ", p->name, p->type); any = 1; free(p); }
        table[cur][i] = NULL;
    }
    printf("%s\n", any ? "" : "(none)");
}
%}

%option noyywrap

ID   [A-Za-z_][A-Za-z0-9_]*

%%
"int"|"float"|"char"|"double"|"void"|"long"|"short"|"unsigned"  {
        in_decl = 1; expect_name = 1; strncpy(curtype, yytext, 23);
    }

"if"|"else"|"while"|"for"|"return"|"do"|"switch"|"case"|"break"|"continue"|"sizeof" {
        in_decl = 0; expect_name = 0;
    }

{ID}  {
        if (in_decl && expect_name) { insert(yytext, curtype, line); expect_name = 0; }
        else {
            int lvl = 0;
            Sym *s = lookup_all(yytext, &lvl);
            if (s) printf("  USE     %-10s -> type=%-7s declared in scope %d, line %d\n",
                          yytext, s->type, lvl, s->line);
            else { printf("  ERROR line %d: '%s' used but never declared\n", line, yytext); errors++; }
        }
    }

"{"   { cur++; if (cur >= MAXSCOPE) { fprintf(stderr, "scope nesting too deep\n"); exit(1); }
        printf("--- entering scope %d\n", cur); in_decl = 0; expect_name = 0; }
"}"   { dump_scope(); if (cur > 0) cur--; in_decl = 0; expect_name = 0; }
","   { if (in_decl) expect_name = 1; }
"="   { expect_name = 0; }
";"   { in_decl = 0; expect_name = 0; }

"//".*                      { }
"/*"([^*]|\*+[^*/])*\*+"/"  { char *p; for (p = yytext; *p; p++) if (*p == '\n') line++; }
[0-9]+(\.[0-9]+)?           { }
\"([^"\\\n]|\\.)*\"         { }
\n                          { line++; }
[ \t\r]+                    { }
.                           { }
%%

int main(int argc, char **argv) {
    if (argc > 1) { yyin = fopen(argv[1], "r"); if (!yyin) { perror(argv[1]); return 1; } }
    printf("=== scope 0 (global) ===\n");
    yylex();
    dump_scope();
    printf("\nTotal semantic errors: %d\n", errors);
    return errors ? 1 : 0;
}
