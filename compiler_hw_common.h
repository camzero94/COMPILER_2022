#ifndef COMPILER_HW_COMMON_H
#define COMPILER_HW_COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

/* Add what you need */

struct stack{
    int value;
    struct stack * prev;
};
struct decl{
    char *name;
    int type;
};
struct symbol  {
    int index;
    char *name;
    int typeName;
    int addr;
    int lineno;
    char *funcSign;
    struct symbol * prevSymbol;
    struct symbol * nextSymbol;

};
struct scope_link {
    struct scope_link * prev_scope_link;
    struct scope_link * next_scope_link;
    struct symbol *firstSymbol;
    struct symbol *lastSymbol;
    int index; 
    
};

#endif /* COMPILER_HW_COMMON_H */
