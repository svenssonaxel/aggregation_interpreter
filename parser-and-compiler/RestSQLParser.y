/*
   Copyright (c) 2024, 2024, Hopsworks and/or its affiliates.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License, version 2.0,
   as published by the Free Software Foundation.

   This program is also distributed with certain software (including
   but not limited to OpenSSL) that is licensed under separate terms,
   as designated in a particular file or component or in included license
   documentation.  The authors of MySQL hereby grant you an additional
   permission to link the program and your derivative works with the
   separately licensed software that they have included with MySQL.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License, version 2.0, for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA
*/

/*
 * RestSQLParser.y is the parser file. The "GNU Project parser generator",
 * `bison', will generate RestSQLParser.y.hpp and RestSQLParser.y.cpp from this
 * file.
 */

%defines "RestSQLParser.y.hpp"
%output "RestSQLParser.y.cpp"
%define api.pure full
%parse-param {yyscan_t scanner}
%lex-param {yyscan_t scanner}
%define api.prefix {rsqlp_}

/* This section will go into RestSQLParser.y.hpp, near the top. */
%code requires
{
typedef void * yyscan_t;
#include "LexString.hpp"
#include "RestSQLPreparer.hpp"
#include "AggregationAPICompiler.hpp"

// Let bison use RestSQLPreparer's arena allocator
#define YYMALLOC(SIZE) context->get_allocator()->alloc(SIZE)
#define YYFREE(PTR) void()

#define yycheck rsqlp_check
#define yydefact rsqlp_defact
#define yydefgoto rsqlp_defgoto
#define yypact rsqlp_pact
#define yypgoto rsqlp_pgoto
#define yyr1 rsqlp_r1
#define yyr2 rsqlp_r2
#define yystos rsqlp_stos
#define yytable rsqlp_table
#define yytranslate rsqlp_translate
}

/* This section will go into RestSQLParser.y.cpp, near the top. */
%code top
{
#include <stdio.h>
#include <stdlib.h>
#include "RestSQLParser.y.hpp"
#include "RestSQLLexer.l.hpp"
extern void rsqlp_error(yyscan_t yyscanner, const char* s);
#define context (rsqlp_get_extra(scanner))
#define initptr(THIS) do \
  { \
    THIS = ((typeof(THIS)) \
            context->get_allocator()->alloc( \
              sizeof(*(THIS)))); \
  } while (0)
#define init_aggfun(RES,FUN,ARG,BEGIN,END) do \
  { \
    initptr(RES); \
    RES->is_agg = true; \
    RES->aggregate.fun = FUN; \
    RES->aggregate.arg = ARG; \
    char* aggfun_begin = BEGIN; \
    char* aggfun_end = END; \
    assert(aggfun_begin < aggfun_end); \
    size_t aggfun_len = aggfun_end - aggfun_begin; \
    RES->output_name = LexString{aggfun_begin, aggfun_len}; \
    RES->next = NULL; \
  } while (0)
#define init_cond(RES,LEFT,OP,RIGHT) do \
  { \
    initptr(RES); \
    RES->args.left = LEFT; \
    RES->op = OP; \
    RES->args.right = RIGHT; \
  } while (0)
}

/* This defines the datatype for an AST node. This includes lexer tokens. */
%union
{
  int ival;
  float fval;
  LexString str;
  struct {
    int type;
    char* begin;
  } pos_keyword;
  struct lsl
  {
    LexString str;
    struct lsl* next;
  } lsl;
  struct Outputs* outputs;
  struct GroupbyColumns* groupby_cols;
  struct ConditionalExpression* conditional_expression;
  AggregationAPICompiler::Expr* arith_expr;
}

%token<ival> T_INT
%token<fval> T_FLOAT
%token T_LEFT
%token<pos_keyword> T_COUNT T_MAX T_MIN T_SUM T_AVG T_RIGHT
%token T_SELECT T_FROM T_GROUP T_BY T_AS T_WHERE
%token T_SEMICOLON
%token T_OR T_XOR T_AND T_NOT T_EQUALS T_GE T_GT T_LE T_LT T_NOT_EQUALS T_IS T_NULL T_BITWISE_OR T_BITWISE_AND T_BITSHIFT_LEFT T_BITSHIFT_RIGHT T_PLUS T_MINUS T_MULTIPLY T_DIVIDE T_MODULO T_BITWISE_XOR T_EXCLAMATION T_INTERVAL

/*
 * MySQL operator presedence, strongest binding first:
 * See https://dev.mysql.com/doc/refman/8.0/en/operator-precedence.html
 *   INTERVAL
 *   BINARY, COLLATE
 *   !
 *   - (unary minus), ~ (unary bit inversion)
 *   ^
 *   *, /, DIV, %, MOD
 *   -, +
 *   <<, >>
 *   &
 *   |
 *   = (comparison), <=>, >=, >, <=, <, <>, !=, IS, LIKE, REGEXP, IN, MEMBER OF
 *   BETWEEN, CASE, WHEN, THEN, ELSE
 *   NOT
 *   AND, &&
 *   XOR
 *   OR, ||
 *   = (assignment), :=
 */

 /* Presedence of implemented operators, strongest binding last */
%left T_OR
%left T_XOR
%left T_AND
%precedence T_NOT
%left T_EQUALS T_GE T_GT T_LE T_LT T_NOT_EQUALS T_IS
%left T_BITWISE_OR
%left T_BITWISE_AND
%left T_BITSHIFT_LEFT T_BITSHIFT_RIGHT
%left T_PLUS T_MINUS
%left T_MULTIPLY T_DIVIDE T_MODULO
%left T_BITWISE_XOR
%precedence T_EXCLAMATION
%left T_INTERVAL


%token T_ERR

%token<str> T_IDENTIFIER
%token T_COMMA

%type<str> identifier
%type<groupby_cols> groupby_opt groupby groupby_cols groupby_col
%type<outputs> outputlist output aliased_output nonaliased_output
%type<pos_keyword> aggfun
%type<arith_expr> arith_expr
%type<conditional_expression> where_opt cond_expr

%start selectstatement

%%

selectstatement:
  T_SELECT outputlist T_FROM identifier where_opt groupby_opt T_SEMICOLON
  {
    context->ast_root.outputs = $2;
    context->ast_root.table = $4;
    context->ast_root.where_expression = $5;
    context->ast_root.groupby_columns = $6;
  }

outputlist:
  output                                { $$ = $1; }
| output T_COMMA outputlist             { $$ = $1; $$->next = $3; }

output:
  aliased_output
| nonaliased_output

aliased_output:
  nonaliased_output T_AS identifier     { $$ = $1; $$->output_name = $3; }

nonaliased_output:
  identifier                            {
                                          initptr($$);
                                          $$->is_agg = false;
                                          $$->col_name = $1;
                                          $$->output_name = $$->col_name;
                                          $$->next = NULL;
                                        }
| aggfun T_LEFT arith_expr T_RIGHT      { init_aggfun($$, $1.type, $3, $1.begin, $4.begin + 1); }
| T_COUNT T_LEFT arith_expr T_RIGHT     {
                                          // This needs to be a separate rule from the "aggfun..."
                                          // rule above in order to avoid a shift/reduce conflict
                                          // with the COUNT(*) rule below.
                                          init_aggfun($$, $1.type, $3, $1.begin, $4.begin + 1);
                                        }
| T_COUNT T_LEFT T_MULTIPLY T_RIGHT     {
                                          // COUNT(*) is implemented as COUNT(1).
                                          init_aggfun($$,
                                                      $1.type,
                                                      context->get_agg()->ConstantInteger(1),
                                                      $1.begin,
                                                      $4.begin + 1);
                                        }

/* T_COUNT not included here, in order to implement COUNT(*) */
aggfun:
  T_AVG                                 { $$ = $1; }
| T_MAX                                 { $$ = $1; }
| T_MIN                                 { $$ = $1; }
| T_SUM                                 { $$ = $1; }

arith_expr:
  identifier                            { $$ = context->get_agg()->Load($1); }
| T_INT                                 { $$ = context->get_agg()->ConstantInteger($1); }
| T_LEFT arith_expr T_RIGHT             { $$ = $2; }
| arith_expr T_PLUS arith_expr          { $$ = context->get_agg()->Add($1, $3); }
| arith_expr T_MINUS arith_expr         { $$ = context->get_agg()->Minus($1, $3); }
| arith_expr T_MULTIPLY arith_expr      { $$ = context->get_agg()->Mul($1, $3); }
| arith_expr T_DIVIDE arith_expr        { $$ = context->get_agg()->Div($1, $3); }
| arith_expr T_MODULO arith_expr        { $$ = context->get_agg()->Rem($1, $3); }

identifier:
  T_IDENTIFIER                          { $$ = $1; }

where_opt:
  %empty                                { $$ = NULL; }
| T_WHERE cond_expr                     { $$ = $2; }

cond_expr:
  identifier                            { initptr($$); $$->op = T_IDENTIFIER; $$->identifier = $1; }
| T_INT                                 { initptr($$); $$->op = T_INT; $$->constant_integer = $1; }
| T_LEFT cond_expr T_RIGHT              { $$ = $2; }
| cond_expr T_OR cond_expr              { init_cond($$, $1, T_OR, $3); }
| cond_expr T_XOR cond_expr             { init_cond($$, $1, T_XOR, $3); }
| cond_expr T_AND cond_expr             { init_cond($$, $1, T_AND, $3); }
| T_NOT cond_expr                       { init_cond($$, $2, T_NOT, NULL); }
| cond_expr T_EQUALS cond_expr          { init_cond($$, $1, T_EQUALS, $3); }
| cond_expr T_GE cond_expr              { init_cond($$, $1, T_GE, $3); }
| cond_expr T_GT cond_expr              { init_cond($$, $1, T_GT, $3); }
| cond_expr T_LE cond_expr              { init_cond($$, $1, T_LE, $3); }
| cond_expr T_LT cond_expr              { init_cond($$, $1, T_LT, $3); }
| cond_expr T_NOT_EQUALS cond_expr      { init_cond($$, $1, T_NOT_EQUALS, $3); }
| cond_expr T_IS T_NULL                 { initptr($$); $$->op = T_IS; $$->is.arg = $1; $$->is.null = true; }
| cond_expr T_IS T_NOT T_NULL           { initptr($$); $$->op = T_IS; $$->is.arg = $1; $$->is.null = false; }
| cond_expr T_BITWISE_OR cond_expr      { init_cond($$, $1, T_BITWISE_OR, $3); }
| cond_expr T_BITWISE_AND cond_expr     { init_cond($$, $1, T_BITWISE_AND, $3); }
| cond_expr T_BITSHIFT_LEFT cond_expr   { init_cond($$, $1, T_BITSHIFT_LEFT, $3); }
| cond_expr T_BITSHIFT_RIGHT cond_expr  { init_cond($$, $1, T_BITSHIFT_RIGHT, $3); }
| cond_expr T_PLUS cond_expr            { init_cond($$, $1, T_PLUS, $3); }
| cond_expr T_MINUS cond_expr           { init_cond($$, $1, T_MINUS, $3); }
| cond_expr T_MULTIPLY cond_expr        { init_cond($$, $1, T_MULTIPLY, $3); }
| cond_expr T_DIVIDE cond_expr          { init_cond($$, $1, T_DIVIDE, $3); }
| cond_expr T_MODULO cond_expr          { init_cond($$, $1, T_MODULO, $3); }
| cond_expr T_BITWISE_XOR cond_expr     { init_cond($$, $1, T_BITWISE_XOR, $3); }
| T_EXCLAMATION cond_expr               { init_cond($$, $2, T_EXCLAMATION, NULL); }
| cond_expr T_INTERVAL cond_expr        { /* todo what? */ init_cond($$, $1, T_INTERVAL, $3); }

groupby_opt:
  %empty                                { $$ = NULL; }
| groupby                               { $$ = $1; }

groupby:
  T_GROUP T_BY groupby_cols             { $$ = $3; }

groupby_cols:
  groupby_col                           { $$ = $1; }
| groupby_col T_COMMA groupby_cols      { $$ = $1; $$->next = $3; }

groupby_col:
identifier                              { initptr($$); $$->col_name = $1; $$->next = NULL; }

%%

void rsqlp_error(yyscan_t scanner, const char *s)
{
  /*
   * Calculate position and length for the last token. We have two cases: For a
   * token stemming from a single lexer rule, we use the values for the last
   * matched lexer rule. For a token stemming from a combination of lexer rules,
   * we have saved the necessary values in m_compound_token_pos and
   * m_compound_token_len.
   */
  char* last_compound_token_pos = context->m_compound_token_pos;
  uint last_compound_token_len = context->m_compound_token_len;
  char* last_match_pos = rsqlp_get_text(scanner);
  uint last_match_len = rsqlp_get_leng(scanner);
  bool last_token_was_compound =
    (last_compound_token_pos + last_compound_token_len) ==
    (last_match_pos + last_match_len);
  char* last_token_pos = last_token_was_compound ?
    last_compound_token_pos : last_match_pos;
  uint last_token_len = last_token_was_compound ?
    last_compound_token_len : last_match_len;
  context->set_err_state(
    RestSQLPreparer::ErrState::PARSER_ERROR,
    last_token_pos,
    last_token_len);
}
