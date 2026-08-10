%{
#include <stdio.h>
%}
%%
[0-9]+\.[0-9]+([eE][+-]?[0-9]+)? { printf("FLOAT: %s\n", yytext); }
[0-9]+[eE][+-]?[0-9]+            { printf("SCIENTIFIC: %s\n", yytext); }
[0-9]+                           { printf("INTEGER: %s\n", yytext); }
[0-9]+\.[0-9]*\.[0-9.]*          { printf("INVALID NUMBER FORMAT: %s\n", yytext); }
[ \t\n\r]+                       { /* Ignore whitespace */ }
.                                { /* Ignore others */ }
%%
int main() { yylex(); return 0; }
int yywrap() { return 1; }
