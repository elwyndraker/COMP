/* Problem 24: same lexer as Problem 23, only the header name changes */
%{
#include <stdlib.h>
#include <string.h>
#include "p24_calc.tab.h"
%}

%option noyywrap
%option yylineno

%%
[ \t\r]+                 { }
\n                       { }
"//".*                   { }
"print"                  { return PRINT; }
[0-9]+(\.[0-9]+)?        { yylval.num = atof(yytext); return NUMBER; }
[A-Za-z_][A-Za-z0-9_]*   { yylval.id  = strdup(yytext); return NAME; }
[-+*/()=;]               { return yytext[0]; }
.                        { fprintf(stderr, "Line %d: lexical error: illegal character '%s'\n",
                                   yylineno, yytext); }
%%
