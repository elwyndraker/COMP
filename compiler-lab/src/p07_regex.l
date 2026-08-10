/* Problem 7: which of  a*  a*b+  (ab)*  abb  does each input line match?
   Build: flex p07_regex.l && gcc lex.yy.c -o p07 && ./p07 ../input/in07.txt   */
%{
#include <stdio.h>
%}

%option noyywrap

%%
^\n         { printf("%-10s -> a*   ,  (ab)*        [empty string]\n", "\"\""); }
^abb$       { printf("%-10s -> abb  ,  a*b+\n", yytext); }
^ab$        { printf("%-10s -> (ab)* ,  a*b+\n", yytext); }
^(ab)+$     { printf("%-10s -> (ab)*\n", yytext); }
^a+$        { printf("%-10s -> a*\n", yytext); }
^a*b+$      { printf("%-10s -> a*b+\n", yytext); }
^[ab]+$     { printf("%-10s -> matches NONE of the four patterns\n", yytext); }
^.+$        { printf("%-10s -> invalid input (not over the alphabet {a,b})\n", yytext); }
\n          { }
%%

int main(int argc, char **argv) {
    if (argc > 1) { yyin = fopen(argv[1], "r"); if (!yyin) { perror(argv[1]); return 1; } }
    printf("STRING      MATCHING PATTERNS\n");
    printf("------------------------------------------\n");
    yylex();
    return 0;
}
