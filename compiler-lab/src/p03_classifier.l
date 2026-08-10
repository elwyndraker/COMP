/* Problem 3: token classifier (KEYWORD / IDENTIFIER / NUMBER / OPERATOR / PUNCTUATION)
   Also prints line + column, so it doubles as Problem 9.
   Build: flex p03_classifier.l && gcc lex.yy.c -o p03 && ./p03 ../input/in03.c   */
%{
#include <stdio.h>
#include <string.h>

int line = 1, col = 1;

static const char *kw[] = {
 "auto","break","case","char","const","continue","default","do","double","else",
 "enum","extern","float","for","goto","if","int","long","register","return",
 "short","signed","sizeof","static","struct","switch","typedef","union",
 "unsigned","void","volatile","while", 0 };

static int is_keyword(const char *s) {
    int i;
    for (i = 0; kw[i]; i++) if (strcmp(s, kw[i]) == 0) return 1;
    return 0;
}

static void report(const char *cls) {
    printf("%-4d %-4d %-14s %s\n", line, col, yytext, cls);
    col += yyleng;
}
%}

%option noyywrap

ID    [A-Za-z_][A-Za-z0-9_]*
NUM   [0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?
OP    "=="|"!="|"<="|">="|"&&"|"||"|"++"|"--"|"+="|"-="|"*="|"/="|"<<"|">>"|"->"|[-+*/%=<>!&|^~]
PUNC  [(){}\[\];,.:?]

%%
[ \t]+                      { col += yyleng; }
\r                          { }
\n                          { line++; col = 1; }
"//".*                      { col += yyleng; }
"/*"([^*]|\*+[^*/])*\*+"/"  { char *p; for (p = yytext; *p; p++) if (*p=='\n') { line++; col = 1; } }

\"([^"\\\n]|\\.)*\"         { report("STRING"); }
'([^'\\\n]|\\.)*'           { report("CHAR"); }
{NUM}                       { report("NUMBER"); }
{ID}                        { report(is_keyword(yytext) ? "KEYWORD" : "IDENTIFIER"); }
{OP}                        { report("OPERATOR"); }
{PUNC}                      { report("PUNCTUATION"); }
.                           { report("UNKNOWN (lexical error)"); }
%%

int main(int argc, char **argv) {
    if (argc > 1) { yyin = fopen(argv[1], "r"); if (!yyin) { perror(argv[1]); return 1; } }
    printf("%-4s %-4s %-14s %s\n", "LN", "COL", "LEXEME", "CLASS");
    printf("-------------------------------------------\n");
    yylex();
    return 0;
}
