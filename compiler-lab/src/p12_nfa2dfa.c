/* Problem 12: NFA -> DFA by subset construction
 *
 * Build : gcc p12_nfa2dfa.c -o p12
 * Run   : ./p12 < ../input/in12.txt
 *
 * INPUT FORMAT
 *   n                 number of NFA states, named 0 .. n-1   (n <= 63)
 *   m                 number of input symbols (epsilon is NOT counted here)
 *   s1 s2 ... sm      the m symbols, e.g.  a b
 *   start             start state
 *   f                 number of final states
 *   q1 ... qf         the final states
 *   t                 number of transitions
 *   from sym to       t lines; write the symbol 'e' for an epsilon move
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

typedef unsigned long long SET;      /* bitmask: bit i set  <=>  NFA state i is in the set */

#define MAXN   63
#define MAXSYM 10
#define MAXD   512

int  n, m, start, nfin;
char sym[MAXSYM][8];
SET  trans[MAXN][MAXSYM];            /* trans[q][c] = set of states reached from q on symbol c */
SET  eps[MAXN];                      /* eps[q]      = set of states reached from q on epsilon  */
int  isFinalNFA[MAXN];

/* ---------- epsilon-closure: keep adding epsilon successors until nothing changes ---------- */
SET closure(SET s) {
    SET res = s;
    int changed = 1, i;
    while (changed) {
        changed = 0;
        for (i = 0; i < n; i++)
            if ((res >> i) & 1ULL) {
                SET t = res | eps[i];
                if (t != res) { res = t; changed = 1; }
            }
    }
    return res;
}

/* ---------- move(S, c): union of trans[q][c] for every q in S ---------- */
SET move(SET s, int c) {
    SET r = 0;
    int i;
    for (i = 0; i < n; i++)
        if ((s >> i) & 1ULL) r |= trans[i][c];
    return r;
}

/* ---------- pretty-print a set as {0,2,4} ---------- */
void printSet(SET s) {
    int i, first = 1;
    putchar('{');
    for (i = 0; i < n; i++)
        if ((s >> i) & 1ULL) { if (!first) putchar(','); printf("%d", i); first = 0; }
    putchar('}');
}

int symIndex(const char *s) {
    int i;
    for (i = 0; i < m; i++) if (strcmp(sym[i], s) == 0) return i;
    return -1;
}

int main(void) {
    int i, j, t, from, to, f;
    char buf[16];

    if (scanf("%d %d", &n, &m) != 2) { fprintf(stderr, "bad input\n"); return 1; }
    for (i = 0; i < m; i++) scanf("%7s", sym[i]);
    scanf("%d", &start);
    scanf("%d", &nfin);
    for (i = 0; i < nfin; i++) { scanf("%d", &f); isFinalNFA[f] = 1; }
    scanf("%d", &t);
    for (i = 0; i < t; i++) {
        scanf("%d %15s %d", &from, buf, &to);
        if (strcmp(buf, "e") == 0 || strcmp(buf, "eps") == 0)
            eps[from] |= 1ULL << to;
        else {
            int c = symIndex(buf);
            if (c < 0) { fprintf(stderr, "unknown symbol %s\n", buf); return 1; }
            trans[from][c] |= 1ULL << to;
        }
    }

    /* ---------- subset construction ---------- */
    SET dstate[MAXD];                 /* dstate[k] = the NFA-state-set that DFA state k stands for */
    int dtrans[MAXD][MAXSYM];         /* -1 means dead / trap state */
    int ndfa = 0;

    dstate[ndfa++] = closure(1ULL << start);   /* A = eps-closure({start}) */

    for (i = 0; i < ndfa; i++) {               /* i grows as we discover new states */
        for (j = 0; j < m; j++) {
            SET u = closure(move(dstate[i], j));
            if (u == 0) { dtrans[i][j] = -1; continue; }
            int k, found = -1;
            for (k = 0; k < ndfa; k++) if (dstate[k] == u) { found = k; break; }
            if (found < 0) { found = ndfa; dstate[ndfa++] = u; }   /* brand-new DFA state */
            dtrans[i][j] = found;
        }
    }

    /* ---------- output ---------- */
    printf("\nDFA states (subset construction):\n");
    for (i = 0; i < ndfa; i++) {
        printf("  %c = ", 'A' + i);
        printSet(dstate[i]);
        int acc = 0;
        for (j = 0; j < n; j++) if (((dstate[i] >> j) & 1ULL) && isFinalNFA[j]) acc = 1;
        printf("%s\n", acc ? "   <-- FINAL" : "");
    }

    printf("\nDFA transition table:\n  state |");
    for (j = 0; j < m; j++) printf(" %5s |", sym[j]);
    printf("\n  ------+");
    for (j = 0; j < m; j++) printf("-------+");
    printf("\n");
    for (i = 0; i < ndfa; i++) {
        printf("   %s%c   |", (i == 0 ? "->" : "  "), 'A' + i);
        for (j = 0; j < m; j++) {
            if (dtrans[i][j] < 0) printf("   --  |");
            else printf("   %c   |", 'A' + dtrans[i][j]);
        }
        printf("\n");
    }
    printf("\n(start state is marked with ->, '--' means dead state)\n");
    return 0;
}
