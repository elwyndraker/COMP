%{
   include<stdio.h>
%}
%X COMMENT
%%
"/*"      {BEGIN (COMMENT); }
<COMMENT> "*/" {BEGIN (INITIAL): }
<COMMENT> .|\n {/*IGNORE MULTILINE*/}
"//".* {/*IGNORE SINGLE LINE*/}
[ \t\r\n]+ {printf (" ");}
.   {printf(" %s ", yytext);}
%%
int main() {yylext(); return 0;}
int yywrap() {return 1;}
