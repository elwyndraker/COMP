/* Problem 5: integer / float(with exponent) / malformed number classifier
   Build: flex p05_numbers.l && gcc lex.yy.c -o p05 && ./p05 ../input/in05.txt   */
%{
#include <stdio.h>
int line = 1;
%}

%option noyywrap

INT     [0-9]+
FLOAT   ([0-9]+\.[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?|[0-9]+[eE][+-]?[0-9]+
BAD     [0-9]+[A-Za-z0-9._]*|\.[0-9]+[A-Za-z0-9._]*
ID      [A-Za-z_][A-Za-z0-9_]*

%%
{FLOAT}   { printf("%-14s FLOAT     (line %d)\n", yytext, line); }
{INT}     { printf("%-14s INTEGER   (line %d)\n", yytext, line); }
{BAD}     { printf("%-14s ERROR: malformed number (line %d)\n", yytext, line); }
{ID}      { printf("%-14s (identifier, not a number)\n", yytext); }
[ \t\r]+  { }
\n        { line++; }
.         { printf("%-14s (other character)\n", yytext); }
%%

int main(int argc, char **argv) {
    if (argc > 1) { yyin = fopen(argv[1], "r"); if (!yyin) { perror(argv[1]); return 1; } }
    yylex();
    return 0;
}
