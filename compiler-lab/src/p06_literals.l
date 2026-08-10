/* Problem 6: string and character literal scanner with escape handling
   Build: flex p06_literals.l && gcc lex.yy.c -o p06 && ./p06 ../input/in06.txt  */
%{
#include <stdio.h>
#include <string.h>
int line = 1;

/* legal single-character escapes in C */
static const char *legal = "ntrbfva\\'\"?0";

static void check_escapes(const char *s) {
    int i;
    for (i = 0; s[i]; i++) {
        if (s[i] == '\\' && s[i+1]) {
            if (!strchr(legal, s[i+1]))
                printf("      warning: unknown escape sequence \\%c on line %d\n", s[i+1], line);
            i++;                       /* skip the escaped character */
        }
    }
}
%}

%option noyywrap

%%
\"([^"\\\n]|\\.)*\"        { printf("%-24s STRING literal  (line %d)\n", yytext, line);
                             check_escapes(yytext); }
\"([^"\\\n]|\\.)*          { printf("%-24s ERROR: unterminated string (line %d)\n", yytext, line); }

'([^'\\\n]|\\.)'           { printf("%-24s CHAR literal    (line %d)\n", yytext, line);
                             check_escapes(yytext); }
'([^'\\\n]|\\.){2,}'       { printf("%-24s ERROR: multi-character char constant (line %d)\n", yytext, line); }
''                         { printf("%-24s ERROR: empty character constant (line %d)\n", yytext, line); }
'([^'\\\n]|\\.)*           { printf("%-24s ERROR: unterminated char constant (line %d)\n", yytext, line); }

[ \t\r]+                   { }
\n                         { line++; }
.                          { }
%%

int main(int argc, char **argv) {
    if (argc > 1) { yyin = fopen(argv[1], "r"); if (!yyin) { perror(argv[1]); return 1; } }
    yylex();
    return 0;
}
