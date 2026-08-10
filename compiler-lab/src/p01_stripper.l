/* Problem 1: Whitespace collapser + comment stripper
   Build:  flex p01_stripper.l && gcc lex.yy.c -o p01 && ./p01 ../input/in01.c   */
%{
#include <stdio.h>

static int pending = 0;   /* we swallowed some whitespace, not yet printed */
static int started = 0;   /* have we printed anything at all yet?          */

static void emit(const char *s) {
    if (pending && started) putchar(' ');  /* one space, never two */
    pending = 0;
    fputs(s, stdout);
    started = 1;
}
%}

%option noyywrap
%x LINE BLOCK          /* exclusive start conditions = "modes" */

%%
    /* ---------- // line comment ---------- */
"//"                { BEGIN(LINE); }
<LINE>\n            { BEGIN(INITIAL); pending = 1; }
<LINE>.             { /* eat comment body */ }
<LINE><<EOF>>       { yyterminate(); }

    /* ---------- slash-star block comment ---------- */
"/*"                { BEGIN(BLOCK); }
<BLOCK>"*/"         { BEGIN(INITIAL); pending = 1; }
<BLOCK>\n           { }
<BLOCK>.            { }
<BLOCK><<EOF>>      { fprintf(stderr, "Error: unterminated block comment\n"); yyterminate(); }

    /* ---------- literals are copied verbatim ---------- */
\"([^"\\\n]|\\.)*\" { emit(yytext); }
'([^'\\\n]|\\.)*'   { emit(yytext); }

    /* ---------- the actual whitespace collapsing ---------- */
[ \t\r\n]+          { pending = 1; }
.                   { emit(yytext); }
%%

int main(int argc, char **argv) {
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) { perror(argv[1]); return 1; }
    }
    yylex();
    putchar('\n');
    return 0;
}
