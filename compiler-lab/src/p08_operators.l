/* Problem 8: validate C operators, reject malformed runs like +* or =+
   Build: flex p08_operators.l && gcc lex.yy.c -o p08 && ./p08 ../input/in08.txt */
%{
#include <stdio.h>
int line = 1, good = 0, bad = 0;
%}

%option noyywrap

OPCHAR  [-+*/%=<>!&|^~?:]

%%
"<<="|">>="                                                { printf("VALID    %-4s (3-char assignment)  line %d\n", yytext, line); good++; }
"=="|"!="|"<="|">="|"&&"|"||"|"++"|"--"                    { printf("VALID    %-4s (2-char operator)    line %d\n", yytext, line); good++; }
"+="|"-="|"*="|"/="|"%="|"&="|"|="|"^="|"<<"|">>"|"->"     { printf("VALID    %-4s (2-char operator)    line %d\n", yytext, line); good++; }
{OPCHAR}                                                   { printf("VALID    %-4s (1-char operator)    line %d\n", yytext, line); good++; }
{OPCHAR}{2,}                                               { printf("INVALID  %-4s <-- malformed operator sequence, line %d\n", yytext, line); bad++; }

[A-Za-z_][A-Za-z0-9_]*  { }
[0-9]+                  { }
[ \t\r(),;{}\[\]]+      { }
\n                      { line++; }
.                       { }
%%

int main(int argc, char **argv) {
    if (argc > 1) { yyin = fopen(argv[1], "r"); if (!yyin) { perror(argv[1]); return 1; } }
    yylex();
    printf("\nSummary: %d valid operator(s), %d malformed sequence(s).\n", good, bad);
    return 0;
}
