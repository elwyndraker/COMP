%{
#include <stdio.h>
%}
%%
abb        { printf("Matches Pattern 4 (abb): %s\n", yytext); }
a*b+       { printf("Matches Pattern 2 (a*b+): %s\n", yytext); }
(ab)+      { printf("Matches Pattern 3 ((ab)*): %s\n", yytext); }
a+         { printf("Matches Pattern 1 (a*): %s\n", yytext); }
[ \t\n\r]+ { /* Ignore whitespace */ }
.          { printf("Unrecognized: %s\n", yytext); }
%%
int main() { yylex(); return 0; }
int yywrap() { return 1; }
