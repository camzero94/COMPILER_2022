/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_hw_common.h" //Extern variables that communicate with lex
    #include <string.h>
    #define YYDEBUG 1
    int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }


    /* UsedC:\Users\User\Desktop\NCKU\COMPILER\HW1\Compiler_F74097015_HW2\compiler_hw2.l to generate code */
    /* As printf; the usage: CODEGEN("%d - %s\n", 100, "Hello world"); */
    /* We do not enforce the use of this macro */
    /* #define CODEGEN(...) \ */
    /*     do { \ */
    /*         for (int i = 0; i < g_indent_cnt; i++) { \ */
    /*             fprintf(fout, "\t"); \ */
    /*         } \ */
    /*         fprintf(fout, __VA_ARGS__); \ */
    /*     } while (0) */

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_scope();
    static void insert_symbol(char * name, int type,  int lineno , int func );
    static struct symbol lookup_symbol_inside_scope(char *name);
    static struct symbol lookup_symbol_global(char *name);
    static void dump_symbol();
    static void dump_global();
    static char* type_get(int type);
    static struct symbol print_type();
    static char type_char(int type);
    static int check_def(int type,char*operator, char * stmntType);
    static int check_mismatch(int type1, int type2, char *op);
    static int check_op(int type, char * op);
    static void load_onto_stack(struct symbol s );
    static void store_onto_local(struct symbol mySymbol);
    static void store_init(struct symbol mySymbol, int is_init_flag);
    static int top_stack();
    static int top_unstack();
    /* Global variables */
    bool g_has_error= false;
    int scope_level = -1;
    int address= -1;
    int type_flag = 0;
    int g_indent_cnt= 0;
    struct stack *currentStack = NULL;
    FILE *fout = NULL;

    struct scope_link globalScope = {NULL,NULL,NULL,NULL,0};
    struct scope_link * current_scope_link = &globalScope;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    char *ident_val;
    struct symbol sym;
    struct decl declaration;
    /* ... */
}

/* Token without return */
%token VAR NEWLINE
%token INT FLOAT BOOL STRING
%token INC DEC GEQ LEQ EQL NEQ LOR LAND
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token IF ELSE FOR SWITCH CASE TRUE FALSE FUNC PACKAGE
%token PRINT PRINTLN 

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <s_val> STRING_LIT
%token <f_val> FLOAT_LIT
%token <ident_val> IDENT

/* Nonterminal with return, which need to sepcify type */
%type <i_val> type 
%type <i_val> expression
%type <i_val> expression_logical_AND expression_comparision expression_equ
%type <i_val> expression_addition expression_multiplication 
%type <declaration> expression_unary expression_postfix  expression_casting
%type <sym> PackageStmt  
%type <declaration> decl expression_basic init_decl stmnt

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList {dump_global();}
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : PackageStmt NEWLINE 
    | FunctionDeclStmt
    | init_decl 
    |decl
    | NEWLINE
    | stmnt
    | stmnt_expression
;


PackageStmt
    : PACKAGE IDENT  {
                            create_scope();
                            printf("package: main");
                            }    
;

FunctionDeclStmt
    : FUNC IDENT  '(' ')'  '{'
    { 
        printf("\nfunc: main\n");
        create_scope();
        printf("func_signature: ()V\n");
        insert_symbol($2,FUNC,yylineno,0);
    } 
    GlobalStatementList '}' {printf("\n");dump_symbol();}
    
     
;

init_decl
    : VAR decl
    { 
      struct decl value = {$2.name,NULL}; $$ = value;
      struct symbol s = lookup_symbol_global($2.name);
      int isInitFlag = $2.type ? 1:0;
      /* fprintf(fout,"Here---------"); */
      store_init(s,isInitFlag);
    }
;
decl
    : IDENT type NEWLINE{
      struct decl value = {$1,NULL};
      $$ = value;
      insert_symbol($1,$2,yylineno,0);
    }

    | IDENT type '=' expression NEWLINE
    {
      struct decl value = {$1,$4};
      $$ = value;
      insert_symbol($1,$2,yylineno,0);
    }
    
;
expression_basic  
    : IDENT 
      {
        struct symbol  s = lookup_symbol_global($1);
        struct decl value = {$1,NULL}; 
        load_onto_stack(s);
        value.name = s.name;
        value.type = s.typeName;
        $$=value; 
      }

    | INT_LIT {fprintf(fout,"ldc %d\n",$1); struct decl value = {NULL,INT};$$ = value;}
    | FLOAT_LIT {fprintf(fout,"ldc %f\n",$1); struct decl value = {NULL,FLOAT};$$ = value;}
    | STRING_LIT{fprintf(fout,"ldc \"%s\"\n",$1); struct decl value = {NULL,STRING};$$ = value;}
    | BOOL {printf("BOOL\n"); struct decl value = {NULL,BOOL};$$ = value;}  
    | TRUE { fprintf(fout,"iconst_1\n"); struct decl value = {NULL,BOOL};$$ = value;}
    | FALSE {fprintf(fout,"iconst_0\n"); struct decl value = {NULL,BOOL};$$ = value;}
    | '(' expression ')' {struct decl value = {NULL,$2}; $$ = value;}
;
expression_postfix 
    : expression_basic {$$=$1;

      /* printf("My Token  %d here basic--------------\n",$1.type); */

} 
    | expression_postfix INC {

    if($1.type == INT || $1.type == BOOL){
      fprintf(fout,"ldc 1\n");
      fprintf(fout,"iadd\n");
    }
    if($1.type == FLOAT){
      fprintf(fout,"ldc 1.0\n");
      fprintf(fout,"fadd\n"); 
    }
    if($1.name != NULL){
      struct symbol s = lookup_symbol_global($1.name);
      store_init(s,1); 
    }
    $$=$1;
    $$.name = NULL;

    }
    | expression_postfix DEC {
      
      if($1.type == INT || $1.type == BOOL){
        
        fprintf(fout,"ldc -1\n");
        fprintf(fout,"iadd\n");
      }
      if($1.type == FLOAT){
        fprintf(fout,"ldc -1.0\n");
        fprintf(fout,"fadd\n"); 
      }
      if($1.name != NULL){
        struct symbol s = lookup_symbol_global($1.name);
        store_init(s,1); 
      }
      $$=$1;
      $$.name = NULL;
      }
;
expression_unary
    : expression_postfix {$$ = $1;

      /* printf("My Token  %d here   unary  --------------",$1.type); */

}
    | '!' expression_casting {
      int frame = top_stack();
      /* fprintf(fout,"Top stack ---> %d\n",frame); */
      struct decl value = $2;
      if($2.type == FLOAT){
        fprintf(fout,"f2i");
      }
      fprintf(fout, "dup\n");
      fprintf(fout, "ifeq L_not_%d\n",frame);
      fprintf(fout, "pop \n");
      fprintf(fout, "iconst_1\n");
      fprintf(fout, "L_not_%d:\n",frame);
      fprintf(fout, "iconst_1\n");
      fprintf(fout, "ixor\n");
      top_unstack();
      value.name = NULL;
      value.type = BOOL;
      $$ = value;

    
    }
    | '+' expression_casting {printf("POS\n");$$.name =NULL; $$=$2;}
    | '-' expression_casting {
    if ($2.type == FLOAT){
     fprintf(fout,"fneg\n");
    }
    if($2.type ==INT){
     fprintf(fout,"ineg\n"); 
    }
     
    $$=$2;
    $$.name = NULL;

    }
    |  INC expression_unary { 
    if($2.type == INT || $2.type == BOOL){
      fprintf(fout,"ldc 1\n");
      fprintf(fout,"iadd\n");
    }
    if($2.type == FLOAT){
      fprintf(fout,"ldc 1.0\n");
      fprintf(fout,"fadd\n"); 
    }
    $$=$2;

    }
    
    |  DEC expression_unary {

      if($2.type == INT || $2.type == BOOL){
        
        fprintf(fout,"ldc -1\n");
        fprintf(fout,"iadd\n");
      }
      if($2.type == FLOAT){
        fprintf(fout,"ldc -1.0\n");
        fprintf(fout,"fadd\n"); 
      }
    $$=$2;

    }
;
expression_casting
    : expression_unary {$$ = $1;

      /* printf("My Token  %d here   casting\n",$1); */
      /* printf("My Token  %d here   casting--------------",$1.type); */

}
    | type '('expression_casting')' {

    struct decl value = $3;
    /* printf("%c2%c\n",type_char($3.type),type_char($1)); */
    if($1 == FLOAT && $3.type != FLOAT ){
      fprintf(fout,"i2f\n");
    }else{
      fprintf(fout,"f2i\n");
    }
    value.type = $1;
    $$ = value;
    }
;

expression_multiplication
    : expression_casting {$$ = $1.type;

      /* printf("My Token  %d here   multiplicatipn\n",$1.type); */

}
    | expression_multiplication '*' expression_casting {
      
      if($1 == FLOAT|| $3.type == FLOAT){
        if($1 != FLOAT){
          fprintf(fout,"swap\n");
          fprintf(fout,"i2f\n");
        }
        if($3.type != FLOAT){
          fprintf(fout,"i2f\n"); 
        }
        fprintf(fout,"fmul\n");
        $$=FLOAT;
      }else{
        fprintf(fout,"imul\n");
        $$=INT;
      }

      /* printf("MUL\n"); */

    }
    | expression_multiplication '/' expression_casting {

      if($1 == FLOAT|| $3.type == FLOAT){
        if($1 != FLOAT){
          
          fprintf(fout,"swap\n");
          fprintf(fout,"i2f\n");
          fprintf(fout,"swap\n");
        }
        if($3.type != FLOAT){
          fprintf(fout,"i2f\n");
        }
        fprintf(fout,"fdiv\n");
        $$=FLOAT;
      }else{
        fprintf(fout,"idiv\n");
        $$=INT;
      }
      /* printf("QUO\n"); */

      }
    | expression_multiplication '%' expression_casting {
      if(check_op($1,"REM") && check_op($3.type,"REM")) {
        check_mismatch($1,$3.type,"REM");
      } 
      fprintf(fout,"irem\n");
      $$=INT;
      /* printf("REM\n"); */
      }
;
expression_addition
    : expression_multiplication {$$ = $1;

      /* printf("My Token  %d here   addition\n",$1); */
}
    | expression_addition '+' expression_multiplication {
      /* printf("My Token  %d,   %d",$1,$3.type); */
      check_mismatch($1,$3,"ADD");
      
      if($1 == FLOAT|| $3 == FLOAT){
        if($1 != FLOAT){
          fprintf(fout,"swap\n");
          fprintf(fout,"i2f\n");
        }
        if($3 != FLOAT){ 
          fprintf(fout,"i2f\n");
        }
        fprintf(fout,"fadd\n");
        $$=FLOAT;
      }else{
        fprintf(fout,"iadd \n");
        $$=INT;
      } 
      /* printf("ADD\n");     */

    }
    | expression_addition '-' expression_multiplication {

      check_mismatch($1,$3,"SUB");
      if($1 == FLOAT|| $3 == FLOAT){
        if($1 != FLOAT){
          fprintf(fout,"swap\n");
          fprintf(fout,"i2f\n");
          fprintf(fout,"swap\n");
        }
        if($3!= FLOAT){ 
          fprintf(fout,"i2f\n");
        }
        fprintf(fout,"fsub\n");
        $$=FLOAT;
      }else{
        fprintf(fout,"isub\n");
        $$=INT;
      }
      /* printf("SUB\n"); */
      }
;
expression_comparision
    : expression_addition{$$ = $1;

      /* printf("My Token  %d here   comp\n",$1); */
}
    | expression_comparision '<' expression_addition 
    {
      int frame = top_stack();
      if($1 == FLOAT || $3 == FLOAT){
        if($1 != FLOAT){
          fprintf(fout,"swap\n");
          fprintf(fout,"i2f\n");
          fprintf(fout,"swap\n");
        } 
        if($3 != FLOAT){
          fprintf(fout,"i2f\n");
        }
          fprintf(fout,"fcmpl\n");
          top_unstack(); 
          $$ = FLOAT;
      }else{
          fprintf(fout,"isub\n");
          $$=INT;
      }
        fprintf(fout,"iflt L_cmp_%d_true\n",frame);
        fprintf(fout,"iconst_0\n");
        fprintf(fout,"goto L_cmp_%d_end",frame);
        fprintf(fout,"L_cmp_%d_true:\n",frame);
        fprintf(fout,"iconst_1\n",frame);
        fprintf(fout,"L_cmp_%d_end:\n",frame);
        top_unstack();
        $$=BOOL; 
    }
    | expression_comparision '>' expression_addition  {printf("GTR\n");

      int frame = top_stack();
      /* fprintf(fout,"Here --> frame %d\n",frame); */
      
      if($1 == FLOAT || $3 == FLOAT){
        if($1 != FLOAT){
          fprintf(fout,"swap\n");
          fprintf(fout,"i2f\n");
          fprintf(fout,"swap\n");
        } 
        if($3 != FLOAT){
          fprintf(fout,"i2f\n");
        }
          fprintf(fout,"swap\n");
          fprintf(fout,"fcmpl\n");
          top_unstack(); 
          $$ = FLOAT;
      }else{

          fprintf(fout,"swap\n");
          fprintf(fout,"isub\n");
          $$=INT;
      }
        fprintf(fout,"iflt L_cmp_%d_true\n",frame);
        /* fprintf(fout,"Now Here --> frame %d\n",frame); */
        fprintf(fout,"iconst_0\n");
        fprintf(fout,"goto L_cmp_%d_end\n",frame);
        fprintf(fout,"L_cmp_%d_true:\n",frame);
        fprintf(fout,"iconst_1\n",frame);
        fprintf(fout,"L_cmp_%d_end:\n",frame);
        top_unstack();
        $$=BOOL; 
}
    | expression_comparision GEQ expression_addition {printf("GEQ\n");

      int frame = top_stack();
      if($1 == FLOAT || $3 == FLOAT){
        if($1 != FLOAT){
          fprintf(fout,"swap\n");
          fprintf(fout,"i2f\n");
          fprintf(fout,"swap\n");
        } 
        if($3 != FLOAT){
          fprintf(fout,"i2f\n");
        }
          fprintf(fout,"fcmpl\n");
          top_unstack(); 
          $$ = FLOAT;
      }else{
          fprintf(fout,"isub\n");
          $$=INT;
      }
        fprintf(fout,"iflt L_cmp_%d_true\n",frame);
        fprintf(fout,"ifeq L_cmp_%d_true\n",frame);
        fprintf(fout,"iconst_0\n");
        fprintf(fout,"goto L_cmp_%d_end\n",frame);
        fprintf(fout,"L_cmp_%d_true:\n",frame);
        fprintf(fout,"iconst_1\n",frame);
        fprintf(fout,"L_cmp_%d_end:\n",frame);
        top_unstack();
        $$=BOOL; 
} 
    | expression_comparision LEQ expression_addition {printf("LEQ\n");

      int frame = top_stack();
      if($1 == FLOAT || $3 == FLOAT){
        if($1 != FLOAT){
          fprintf(fout,"swap\n");
          fprintf(fout,"i2f\n");
          fprintf(fout,"swap\n");
        } 
        if($3 != FLOAT){
          fprintf(fout,"i2f\n");
        }
          fprintf(fout,"swap\n");
          fprintf(fout,"fcmpl\n");
          top_unstack(); 
          $$ = FLOAT;
      }else{
          fprintf(fout,"swap\n");
          fprintf(fout,"isub\n");
          $$=INT;
      }
        fprintf(fout,"iflt L_cmp_%d_true\n",frame);
        fprintf(fout,"ifeq L_cmp_%d_true\n",frame);
        fprintf(fout,"iconst_0\n");
        fprintf(fout,"goto L_cmp_%d_end\n",frame);
        fprintf(fout,"L_cmp_%d_true:\n",frame);
        fprintf(fout,"iconst_1\n",frame);
        fprintf(fout,"L_cmp_%d_end:\n",frame);
        top_unstack();
        $$=BOOL; 
}
;   
expression_equ
    : expression_comparision {$$ = $1;

      /* printf("My Token  %d here   equ\n",$1); */

}
    | expression_equ EQL expression_addition {printf("EQL\n");$$ = BOOL;}
    | expression_equ NEQ expression_addition {printf("NEQ\n");$$ = BOOL;}
;
expression_logical_AND
    : expression_equ{$$= $1;

}
    | expression_logical_AND LAND expression_comparision 
    {
      if(check_op($1,"LAND") && check_op($3,"LAND")) {
        check_mismatch($1,$3,"LAND");
      } 
      fprintf(fout,"iand\n");
      /* printf("LAND\n"); */
      $$=BOOL;
    } 
;
expression
    : expression_logical_AND {$$ = $1;
      /* printf("My Token  %d here   expr\n",$1); */
}
    | expression  LOR  expression_logical_AND {

      if(check_op($1,"LOR") && check_op($3,"LOR")) {
        check_mismatch($1,$3,"LOR");
      } 
      fprintf(fout,"ior\n");
      /* printf("LOR\n"); */
      $$=BOOL;
    } 
;
    

type 
    : INT {$$ = INT;}
    | FLOAT {$$ = FLOAT;}
    | STRING {$$ = STRING;}
    | BOOL {$$ = BOOL;}
    | FUNC {$$ = FUNC;}
;

stmnt_expression 
    : def 
    | expression{}
;

if_stmnt
    : IF expression {check_op($2,"IF");}stmnt      
;|

stmnt 
    : PRINTLN '(' expression ')' 
    {
      /* struct symbol s = print_type();  */
      if($3 == BOOL) {
        
        int frame = top_stack();
        fprintf(fout,"ifne L_cmp_%d_true\n",frame);
        /* fprintf(fout,"else:\n"); */
        fprintf(fout,"ldc \"false\"\n");
        fprintf(fout,"goto L_cmp_%d_end\n",frame);
        fprintf(fout,"L_cmp_%d_true:\n",frame);
        /* fprintf(fout,"iconst_1\n",frame); */
        fprintf(fout,"ldc \"true\"\n");
        fprintf(fout,"L_cmp_%d_end:\n",frame);
        top_unstack();
      }
      fprintf(fout,"getstatic java/lang/System/out Ljava/io/PrintStream;\n");
      fprintf(fout,"swap\n");
      if($3 == FLOAT){  
        fprintf(fout,"invokevirtual java/io/PrintStream/println(F)V\n");
      }
      if($3 == INT){
        fprintf(fout,"invokevirtual java/io/PrintStream/println(I)V\n"); 
      }
      if($3 == STRING || $3==BOOL){
        fprintf(fout,"invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n"); 
      }
       yylineno++; 
      /* printf("PRINTLN %s\n",type_get($3)); */
    } 
    | PRINT '(' expression ')' 
    {
      if($3 == BOOL) {
        
        int frame = top_stack();
        fprintf(fout,"ifne L_cmp_%d_true\n",frame);
        /* fprintf(fout,"else:\n"); */
        fprintf(fout,"ldc \"false\"\n");
        fprintf(fout,"goto L_cmp_%d_end\n",frame);
        fprintf(fout,"L_cmp_%d_true:\n",frame);
        fprintf(fout,"iconst_1\n",frame);
        fprintf(fout,"ldc \"true\"\n");
        fprintf(fout,"L_cmp_%d_end:\n",frame);
        top_unstack();
      }
      fprintf(fout,"getstatic java/lang/System/out Ljava/io/PrintStream;\n");
      fprintf(fout,"swap\n");
      if($3 == FLOAT){  
        fprintf(fout,"invokevirtual java/io/PrintStream/print(F)V\n");
      }
      if($3 == INT){
        fprintf(fout,"invokevirtual java/io/PrintStream/print(I)V\n"); 
      }
      if($3 == STRING || $3==BOOL){
        fprintf(fout,"invokevirtual java/io/PrintStream/print(I)V\n"); 
      }
      /* struct symbol s = print_type();  */
      printf("PRINT %s\n",type_get($3));
    } 
    /* | IDENT INC  */
    /*   { */
        /* if($1 != NULL){ */
        /*   fprintf(fout,"dup\n"); */
        /* } */
        /*  printf("IDENT (name=%s, address=%d)\n",s.name,s.addr);struct decl value = {$1,NULL}; $$=value;  */ 
        /*  printf("INC\n"); */ 
        /* if($1 == INT || $1 == BOOL){ */
        /*   fprintf(fout,"ldc 1\n"); */
        /*   fprintf(fout,"iadd\n"); */
        /* } */
        /* if($1 == FLOAT){ */
        /*   fprintf(fout,"ldc 1.0\n"); */
        /*   fprintf(fout,"fadd\n");  */
        /* } */
        /* if($1 != NULL){ */
        /*   struct symbol  s = lookup_symbol_global($1); */
        /*   store_init(s,1); */
        /* } */
          /* fprintf(fout,"$1---->>> %s\n",$1);  */

      /* } */
    /* | IDENT DEC  */
    /*   { */
    /*     struct symbol  s = lookup_symbol_global($1); */
        /* printf("IDENT (name=%s, address=%d)\n",s.name,s.addr);struct decl value = {$1,NULL}; $$=value;  */
        /* printf("DEC\n"); */
        /* if(s.typeName == INT || s.typeName == BOOL){ */
        /*   fprintf(fout,"ldc -1\n"); */
        /*   fprintf(fout,"iadd\n"); */
        /* } */
        /* if(s.typeName == FLOAT){ */
        /*   fprintf(fout,"ldc -1.0\n"); */
        /*   fprintf(fout,"fadd\n");  */
        /* } */
      /* } */
    | scope
    | if_stmnt
    | FOR {
      int frame = top_stack();
      fprintf(fout, "loop_begin_%d:\n",top_frame());
    } expression {

      /* check_op($2,"FOR"); */
      fprintf(fout, "goto loop_stmnt_%d\n",top_frame());
      fprintf(fout, "loop_%d_last:\n",top_frame());

      /* fprintf(fout, "pop\n"); */
      fprintf(fout, "goto loop_begin_%d\n",top_frame());
      fprintf(fout, "loop_stmnt_%d:\n",top_frame());
      fprintf(fout, "ifeq for_end_%d\n",top_frame());

    }
      stmnt{
      int frame = top_unstack(); 
      fprintf(fout, "goto loop_%d_last\n",frame);
      fprintf(fout, "for_end_%d:\n",frame);

    }

    | NEWLINE
    

;

def
    : expression_unary '=' expression {
    check_mismatch($1.type,$3,"ASSIGN");
    store_init(lookup_symbol_global($1.name),1);

    /* fprintf(fout, "Here ------"); */
    /* printf("ASSIGN\n"); */


    }
    | expression_unary REM_ASSIGN expression {

      struct symbol s = lookup_symbol_global($1.name);
      fprintf(fout,"irem\n");
      store_init(s,1);
    } 
    | expression_unary ADD_ASSIGN expression {

      struct symbol s = lookup_symbol_global($1.name);
      if($1.type == FLOAT || $3 == FLOAT){
        if($1.type != FLOAT){
          fprintf(fout, "swap\n");
          fprintf(fout, "i2f\n");
        }
        if($3 != FLOAT){
          fprintf(fout, "i2f\n");
        }else{
          fprintf(fout, "fadd\n");
        }
      }else{
          fprintf(fout, "iadd\n");
      }
      store_init(s,1);

    } 
    | expression_unary SUB_ASSIGN expression {
      struct symbol s = lookup_symbol_global($1.name);
      if($1.type == FLOAT || $3 == FLOAT){
        if($1.type != FLOAT){
          fprintf(fout, "swap\n");
          fprintf(fout, "i2f\n");
        }
        if($3 != FLOAT){
          fprintf(fout, "i2f\n");
        }else{
          fprintf(fout, "fsub\n");
        }
      }else{
          fprintf(fout, "isub\n");
      }
      store_init(s,1);

    } 
    | expression_unary QUO_ASSIGN expression {

      struct symbol s = lookup_symbol_global($1.name);
      if($1.type == FLOAT || $3 == FLOAT){
        if($1.type != FLOAT){
          fprintf(fout, "swap\n");
          fprintf(fout, "i2f\n");
        }
        if($3 != FLOAT){
          fprintf(fout, "i2f\n");
        }else{
          fprintf(fout, "fdiv\n");
        }
      }else{
          fprintf(fout, "idiv\n");
      }
      store_init(s,1);

    } 
    | expression_unary MUL_ASSIGN expression {
      
      struct symbol s = lookup_symbol_global($1.name);
      if($1.type == FLOAT || $3 == FLOAT){
        if($1.type != FLOAT){
          fprintf(fout, "swap\n");
          fprintf(fout, "i2f\n");
        }
        if($3 != FLOAT){
          fprintf(fout, "i2f\n");
        }else{
          fprintf(fout, "fmul\n");
        }
      }else{
          fprintf(fout, "imul\n");
      }
      store_init(s,1);
    }
;

scope
    : '{' {create_scope();}
      
    
    /* printf("Im here global "); */
  
      GlobalStatementList    '}' {printf("\n");dump_symbol();}
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

    if (!yyin) {
        printf("file `%s` doesn't exists or cannot be opened\n", argv[1]);
        exit(1);
    }

    /* Codegen output init */
    char *bytecode_filename = "hw3.j";
    fout = fopen(bytecode_filename, "w");
    
    fprintf(fout, ".source hw3.j\n");
    fprintf(fout, ".class public Main\n");
    fprintf(fout, ".super java/lang/Object\n");
    fprintf(fout, ".method public static main([Ljava.lang/String;)V\n");
    fprintf(fout, ".limit stack 100\n");
    fprintf(fout, ".limit locals 100\n");
    
    /* Symbol table init */
    // Add your code
    yylineno = 0;
    yyparse();

    fprintf(fout, "return\n");
    fprintf(fout, ".end method\n");
	  /* printf("Total lines: %d\n", yylineno); */
    fclose(fout);
    fclose(yyin);

    if (g_has_error) {
      
      /* fprintf(fout, "ldc \"hw3 does not exist\"\n"); */
      /* fprintf(fout,"getstatic java/lang/System/out Ljava/io/PrintStream;\n"); */
      /* fprintf(fout,"swap\n"); */
      /* fprintf(fout,"invokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");  */
        remove(bytecode_filename);
    }
    yylex_destroy();
    return 0;
}

static void create_scope() {
    struct scope_link * newScope = (struct scope_link*)malloc(sizeof(struct scope_link));
    newScope->firstSymbol= NULL;
    newScope->lastSymbol = NULL;
    newScope->index = -1;
    newScope->next_scope_link =NULL;
    newScope->prev_scope_link = current_scope_link; 

    current_scope_link->next_scope_link = newScope;
    current_scope_link = newScope;

    scope_level++;
    printf("> Create symbol table (scope level %d)\n", scope_level);
}

static void insert_symbol(char *name, int type,  int lineno, int func) {
    
    struct symbol * current = malloc(sizeof(struct symbol));
    current->name = name;
    current->typeName = type;
    /* printf("%d---->%s",type,type_get(type)); */
    current->addr = address;
    current->lineno = lineno;
    if(!func)
      current->funcSign = "- ";
    current->nextSymbol = NULL;
    address++;
    if(!strcmp(type_get(current->typeName),"func")){
      current->prevSymbol = current_scope_link->prev_scope_link->firstSymbol; 

      current->index = -1;
      current->lineno++;
      /* printf("Current Scope Index %d\n",current_scope_link->index); */
      /* printf("Scope Number %d",scope_level); */
      current_scope_link->prev_scope_link->index++;
      printf("> Insert `%s` (addr: %d) to scope level %d\n", name,current->addr,scope_level-1);
      current_scope_link->prev_scope_link->firstSymbol = current;
      current_scope_link->prev_scope_link->lastSymbol= current;
      /* printf("Inside Main %s",current_scope_link->firstSymbol->name); */
      /* printf("%s",current_scope_link->prev_scope_link->firstSymbol->name); */
      return;
 
    }
    if(current_scope_link->firstSymbol == NULL ){
      /* printf("Name to be inserted%s, scope is %d, the last scope lastSym is %s\n",current->name,scope_level, */
      /* current_scope_link->prev_scope_link->lastSymbol->name); */
      current->prevSymbol = (scope_level)? current_scope_link->prev_scope_link->lastSymbol:NULL;
      current->index = 0;
      /* printf("Inside Current Scope Index %d",current_scope_link->index); */
      current_scope_link->index++;
      printf("> Insert `%s` (addr: %d) to scope level %d\n", name,current->addr,scope_level);
      current_scope_link->firstSymbol = current;
      current_scope_link->lastSymbol = current;

      return;
    }

    /* printf(" Outside Current Scope Index %d",current_scope_link->index); */
    current_scope_link->index++;
    current->index = current_scope_link->index;
    current-> prevSymbol = current_scope_link->lastSymbol;
    current_scope_link->lastSymbol->nextSymbol = current;
    current_scope_link->lastSymbol = current;
    printf("> Insert `%s` (addr: %d) to scope level %d\n", name,current->addr,scope_level);


}

static struct symbol  lookup_symbol_inside_scope(char *name) {
    struct symbol * symb_found;   
    for (symb_found = current_scope_link->firstSymbol; symb_found != NULL && strcmp(name,symb_found->name);
         symb_found = symb_found->nextSymbol);
    return *symb_found;
}

static void dump_global(){
    struct  symbol * symb_found; 
    printf("\n> Dump symbol table (scope level: 0)\n");
    printf("%-10s%-10s%-10s%-10s%-10s%s\n", "Index", "Name", "Type", "Addr", "Lineno",
    "Func_sig  ");
    /* printf("Current fistSymb %s\n",current_scope_link->firstSymbol->name); */
    for (symb_found = current_scope_link->firstSymbol; symb_found != NULL; symb_found = symb_found->nextSymbol){

        printf("%-10d%-10s%-10s%-10d%-10d%s\n", current_scope_link->index,symb_found->name,
        type_get(symb_found->typeName),symb_found->addr,symb_found->lineno,"()V       \n");
         
    }

}
static void dump_symbol() {
  
    struct symbol * symb_found;
    struct scope_link * p_scope_found = current_scope_link->prev_scope_link;

    printf("> Dump symbol table (scope level: %d)\n", scope_level);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s\n",
           "Index", "Name", "Type", "Addr", "Lineno", "Func_sig");

    /* printf("Current Scope First  %s\n",current_scope_link->firstSymbol->name); */
    for (symb_found = current_scope_link->firstSymbol;symb_found != NULL ;
         symb_found = symb_found->nextSymbol){
            /* printf("We are in %s\n",symb_found->name); */
            if(symb_found != current_scope_link->firstSymbol) {
              free(symb_found->prevSymbol);
            }
            printf("%-10d%-10s%-10s%-10d%-10d%-10s\n",
            symb_found->index, symb_found->name,type_get(symb_found->typeName),
            symb_found->addr,symb_found->lineno, "-");
    }
    printf("\n");
    free(current_scope_link->lastSymbol);
    p_scope_found->next_scope_link = NULL;
    free(current_scope_link);
    current_scope_link = p_scope_found;
    scope_level--;

}

char type_char(int type){


    if(type == INT){
      return 'i';
    }
    
    if(type == FLOAT){
      return 'f';
    }
    if(type == STRING){
      return 's';
    } 
    if(type == BOOL){
      return 'b';
    }
    return "";



}
char* type_get(int type){

    /* printf("%d",type); */
    if(type == FUNC){
      return "func";
    }

    if(type == INT){
      return "int32";
    }
    
    if(type == FLOAT){
      return "float32";
    }
    if(type == STRING){
      return "string";
    } 
    if(type == BOOL){
      return "bool";
    }
    return "";


}
static struct symbol lookup_symbol_global(char *name){
    struct symbol * symb_found;
    struct scope_link * scope_found;
    /* printf("Name is : %s",name); */
    scope_found = current_scope_link;
    while(scope_found->prev_scope_link != NULL &&
          scope_found->lastSymbol == NULL)
            scope_found =scope_found->prev_scope_link;

    for (symb_found = scope_found->lastSymbol; symb_found != NULL && strcmp(name,symb_found->name); 
        symb_found = symb_found->prevSymbol);
    if(symb_found == NULL){
      struct symbol dumm = {-1,NULL,-1,-1,-1,NULL,NULL,NULL };
      return dumm;
    }

    return *symb_found;

}
static struct symbol print_type(){
    struct symbol * last_symb;
    /* printf("%d",current_scope_link->lastSymbol->typeName); */
    /* for (last_symb = current_scope_link->firstSymbol; last_symb != NULL; */
    /*      last_symb = last_symb->nextSymbol); */
    /* if(last_symb == NULL) { */
    /*   printf("NULL"); */
    /*   return; */
    /* } */
    if(current_scope_link->lastSymbol){
      return *current_scope_link->lastSymbol;
    }
    return ;
      
}
static int check_op(int type, char * op){
  char * type_str = type_get(type) ;
  char buffer [100] = ""; 
  if(!strcmp(op,"REM")){
    if(!strcmp(type_str,"int32")){
      return 1;
    }
    sprintf(buffer,"invalid operation: (operator REM not defined on %s)",type_str); 
    yyerror(buffer);
    return 0; 
  }
  else if(!strcmp(op,"LAND")){
    if(!strcmp(type_str,"bool") ){
      return 1;
    }
    sprintf(buffer,"invalid operation: (operator LAND not defined on %s)",type_str); 
    yyerror(buffer);
    return 0; 
  
  }
  else if(!strcmp(op,"LOR")){
    if(!strcmp(type_str,"bool")){
      return 1;
    }
    sprintf(buffer,"invalid operation: (operator LOR not defined on %s)",type_str); 
    yyerror(buffer);
    return 0; 
  
  }
  else if(!strcmp(op,"FOR")){
    if(!strcmp(type_str,"bool")){
      return 1;
    }
    sprintf(buffer,"non-bool (type %s) used as for condition",type_str); 
    yylineno++;
    yyerror(buffer);
    yylineno--;
    return 0; 
  
  }
  else if(!strcmp(op,"IF")){
    if(!strcmp(type_str,"bool")){
      return 1;
    }
    sprintf(buffer,"non-bool (type %s) used as for condition",type_str); 
    yylineno++;
    yyerror(buffer);
    yylineno--;
    return 0; 
  
  }
   
 return 0; 

}
static int check_mismatch(int type1, int type2, char *op){
  if(type1 != type2){
   char buffer[100] = "";
   sprintf(buffer,"invalid operation: %s (mismatched types %s and %s)"
   ,op,type_get(type1),type_get(type2));
    yyerror(buffer);
    g_has_error = true;
   return 0;  
   }
   return 1;
}

static void load_onto_stack(struct symbol s ){
  if(!strcmp(type_get(s.typeName),"int32") || !strcmp(type_get(s.typeName),"bool") )   {
    fprintf(fout,"iload %d\n",s.addr);
    return;
  }
  if(!strcmp(type_get(s.typeName),"float32"))   {
    fprintf(fout,"fload %d\n",s.addr);
    return;
  }
  if(!strcmp(type_get(s.typeName),"string"))   {
    fprintf(fout,"aload %d\n",s.addr);
    return;
  }

}
static void store_onto_local(struct symbol mySymbol){
  
  
}
static void store_init(struct symbol initSymbol, int is_init_flag){

  /* fprintf(fout,"is_init---> %d\n",is_init_flag); */
  if(!strcmp(type_get(initSymbol.typeName), "int32") || !strcmp(type_get(initSymbol.typeName),"bool") ) { 
    if (!is_init_flag)
      fprintf(fout,"iconst_0 \n");

    fprintf(fout,"istore %d\n", initSymbol.addr);
    return;
  }
  if(!strcmp(type_get(initSymbol.typeName), "float32")  ) { 
    if (!is_init_flag)
      fprintf(fout,"ldc 0.0\n");

    fprintf(fout,"fstore %d\n", initSymbol.addr);
    return;
  }
  if(!strcmp(type_get(initSymbol.typeName), "string")  ) { 
    if (!is_init_flag)
      fprintf(fout,"ldc \"\"\n");

    fprintf(fout,"astore %d\n", initSymbol.addr);
    return;
  }

}
static int top_stack(){
  int top = 0;
  if(currentStack == NULL){
    currentStack = malloc(sizeof(struct stack));
    currentStack->value = top++;
    currentStack->prev = NULL;
  }
  int newVal = top++;
  struct stack *new_currStack = malloc(sizeof(struct stack));
  new_currStack->value = newVal;
  new_currStack->prev= currentStack; 
  currentStack = new_currStack;
  return top; 
}
static int top_unstack(){

  if(currentStack ==NULL){
    yyerror("Error Stack is empty");
    exit(0);
  }
  struct stack * prevStack = currentStack->prev;
  /* fprintf(fout,"CURRUNSTACK---> Val%d\n",currentStack->value); */
  int popped = currentStack->value;
  free(currentStack);
  currentStack = prevStack;
  return popped;
}

int top_frame(){
  return currentStack->value;
}

