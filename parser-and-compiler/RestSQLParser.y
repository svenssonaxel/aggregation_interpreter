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
  struct GroupbyColumns* groupby_columns;
  AggregationAPICompiler::Expr* arith_expr;
}

%token<ival> T_INT
%token<fval> T_FLOAT
%token T_PLUS T_MINUS T_MULTIPLY T_DIVIDE T_MODULO T_LEFT
%token<pos_keyword> T_COUNT T_MAX T_MIN T_SUM T_RIGHT
%token T_SELECT T_FROM T_GROUP T_BY T_AS
%token T_SEMICOLON

%left T_PLUS T_MINUS
%left T_MULTIPLY T_DIVIDE T_MODULO

%token T_ERR

%token<str> T_IDENTIFIER
%token T_COMMA

%type<str> identifier
%type<groupby_columns> groupby_opt groupby groupby_columns groupby_column
%type<outputs> outputlist output aliased_output nonaliased_output
%type<pos_keyword> aggfun
%type<arith_expr> arith_expr

%start selectstatement

%%

selectstatement: T_SELECT outputlist T_FROM identifier groupby_opt T_SEMICOLON
                 {
                   context->ast_root.outputs = $2;
                   context->ast_root.table = $4;
                   context->ast_root.groupby_columns = $5;
                 }

outputlist: output
            {
              $$ = $1;
            }
          | output T_COMMA outputlist
            {
              $$ = $1;
              $$->next = $3;
            }

output: aliased_output
      | nonaliased_output

aliased_output: nonaliased_output T_AS identifier
                {
                  $$ = $1;
                  $$->output_name = $3;
                }

nonaliased_output: identifier
                   {
                     initptr($$);
                     $$->is_agg = false;
                     $$->col_name = $1;
                     $$->output_name = $$->col_name;
                     $$->next = NULL;
                   }
                 | aggfun T_LEFT arith_expr T_RIGHT
                   {
                     initptr($$);
                     $$->is_agg = true;
                     $$->aggregate.fun = $1.type;
                     $$->aggregate.arg = $3;
                     char* aggfun_begin = $1.begin;
                     char* aggfun_end = $4.begin + 1;
                     assert(aggfun_begin < aggfun_end);
                     size_t aggfun_len = aggfun_end - aggfun_begin;
                     $$->output_name = LexString{aggfun_begin, aggfun_len};
                     $$->next = NULL;
                   }

aggfun: T_COUNT
        {
          $$ = $1;
        }
      | T_MAX
        {
          $$ = $1;
        }
      | T_MIN
        {
          $$ = $1;
        }
      | T_SUM
        {
          $$ = $1;
        }

arith_expr: identifier
            {
              $$ = context->get_agg()->Load($1);
            }
          | T_INT
            {
                $$ = context->get_agg()->ConstantInteger($1);
            }
          | T_LEFT arith_expr T_RIGHT
            {
              $$ = $2;
            }
          | arith_expr T_PLUS arith_expr
            {
              $$ = context->get_agg()->Add($1, $3);
            }
          | arith_expr T_MINUS arith_expr
            {
              $$ = context->get_agg()->Minus($1, $3);
            }
          | arith_expr T_MULTIPLY arith_expr
            {
              $$ = context->get_agg()->Mul($1, $3);
            }
          | arith_expr T_DIVIDE arith_expr
            {
              $$ = context->get_agg()->Div($1, $3);
            }
          | arith_expr T_MODULO arith_expr
            {
              $$ = context->get_agg()->Rem($1, $3);
            }

identifier: T_IDENTIFIER
            {
              $$ = $1;
            }

groupby_opt: {
               $$ = NULL;
             }
           | groupby
             {
               $$ = $1;
             }

groupby: T_GROUP T_BY groupby_columns
         {
           $$ = $3;
         }

groupby_columns: groupby_column
                 {
                   $$ = $1;
                 }
               | groupby_column T_COMMA groupby_columns
                 {
                   $$ = $1;
                   $$->next = $3;
                 }

groupby_column: identifier
                {
                  initptr($$);
                  $$->col_name = $1;
                  $$->next = NULL;
                }

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
