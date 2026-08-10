%{
#include <stdio.h>
%}
%%
\"([^"\n]|\\.)*\" { printf("STRING LITERAL: %s\n", yytext); }
'([^'\n]|\\.)+'   { printf("CHARACTER LITERAL: %s\n", yytext); }
\"([^"\n]|\\.)*   { printf("LEXICAL ERROR: Unterminated string %s\n", yytext); }
'([^'\n]|\\.)*    { printf("LEXICAL ERROR: Unterminated char %s\n", yytext); }
[ \t\n\r]+        { /* Ignore whitespace */ }
.                 { /* Ignore others */ }
%%
int main() { yylex(); return 0; }
int yywrap() { return 1; }
