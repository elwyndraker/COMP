%{
#include <stdio.h>
%}
%%
"++"|"--"|"=="|"!="|"<="|">="|"&&"|"||"|"+"|"-"|"*"|"/"|"="|"+="|"-="|"*="|"/="|"%="|"<<"|">>"|"->" {
    printf("VALID OPERATOR: %s\n", yytext);
}
("+"|"-"|"*"|"/"|"="){2,} {
    printf("MALFORMED OPERATOR ERROR: %s\n", yytext);
}
[ \t\n\r]+ { /* Ignore whitespace */ }
.          { /* Ignore others */ }
%%
int main() { yylex(); return 0; }
int yywrap() { return 1; }
