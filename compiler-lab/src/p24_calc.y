/* Problem 24: Problem 23 + panic-mode error recovery using Bison's `error` token.
   Build:
       bison -d p24_calc.y
       flex  p24_calc.l
       gcc p24_calc.tab.c lex.yy.c -o p24
   Run: ./p24 < ../input/in24.txt                                            */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int  yylex(void);
void yyerror(const char *s);
extern int yylineno;

int syntax_errors = 0;

#define MAXVAR 200
static struct { char *name; double val; } tab[MAXVAR];
static int nvar = 0;

static int find(const char *n) {
    int i; for (i = 0; i < nvar; i++) if (strcmp(tab[i].name, n) == 0) return i; return -1;
}
static void setvar(const char *n, double v) {
    int i = find(n);
    if (i >= 0) { tab[i].val = v; return; }
    tab[nvar].name = strdup(n); tab[nvar].val = v; nvar++;
}
static double getvar(const char *n, int *ok) {
    int i = find(n); if (i < 0) { *ok = 0; return 0.0; } *ok = 1; return tab[i].val;
}
%}

%define parse.error verbose      /* older bison: replace this line with  %error-verbose */

%union { double num; char *id; }

%token <num> NUMBER
%token <id>  NAME
%token       PRINT
%type  <num> expr

%left  '+' '-'
%left  '*' '/'
%right UMINUS

%%
program : /* empty */
        | program stmt
        ;

stmt : NAME '=' expr ';'   { setvar($1, $3); printf("%s = %g\n", $1, $3); free($1); }
     | PRINT expr ';'      { printf("= %g\n", $2); }
     | expr ';'            { printf("= %g\n", $1); }
     | error ';'           { yyerrok;                                   /* panic mode:  */
                             printf("   ...recovered, skipped to ';'\n"); }
     ;

expr : NUMBER              { $$ = $1; }
     | NAME                { int ok; $$ = getvar($1, &ok);
                             if (!ok) fprintf(stderr, "Line %d: semantic warning: '%s' undefined, using 0\n",
                                              yylineno, $1);
                             free($1); }
     | expr '+' expr       { $$ = $1 + $3; }
     | expr '-' expr       { $$ = $1 - $3; }
     | expr '*' expr       { $$ = $1 * $3; }
     | expr '/' expr       { if ($3 == 0) { fprintf(stderr, "Line %d: division by zero\n", yylineno); $$ = 0; }
                             else $$ = $1 / $3; }
     | '-' expr %prec UMINUS { $$ = -$2; }
     | '(' expr ')'        { $$ = $2; }
     ;
%%

void yyerror(const char *s) {
    syntax_errors++;
    fprintf(stderr, "Line %d: syntax error: %s\n", yylineno, s);
}

int main(void) {
    yyparse();
    printf("\n--- final symbol table ---\n");
    { int i; for (i = 0; i < nvar; i++) printf("  %-10s = %g\n", tab[i].name, tab[i].val); }
    printf("\nParsing finished with %d syntax error(s).\n", syntax_errors);
    return syntax_errors ? 1 : 0;
}
