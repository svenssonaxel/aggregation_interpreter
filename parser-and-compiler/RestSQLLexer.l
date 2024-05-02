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
 * RestSQLLexer.l is the lexer file. The "fast lexical analyser generator",
 * `flex', will generate RestSQLLexer.l.hpp and RestSQLLexer.l.cpp from this
 * file.
 */

%option noyywrap
%option warn
%option nodefault
%option reentrant
%option outfile="RestSQLLexer.l.with-yy_hold_char.cpp"
%option header="RestSQLLexer.l.hpp"
%option bison-bridge
%option extra-type="RestSQLPreparer::Context*"
%option prefix="rsqlp_"
%option case-insensitive
%option batch
/* todo experiment with optimization options
 * Probably use %option fast
 * but also try %option full
 * See https://www.cs.virginia.edu/~cr4bd/flex-manual/Options-for-Scanner-Speed-and-Size.html
 */
%option perf-report

/* Suppress built-in allocator */
%option noyyalloc
%option noyyfree
%option noyyrealloc

/* Suppress functions we don't use */
%option noinput
%option nounput
%option noyy_pop_state
%option noyy_push_state
%option noyy_top_state
%option noyyget_debug
%option noyyget_in
%option noyyget_lineno
%option noyyget_lloc
%option noyyget_lval
%option noyyget_out
%option noyyset_debug
%option noyyset_in
%option noyyset_lineno
%option noyyset_lloc
%option noyyset_lval
%option noyyset_out

/*
 * This section will go into both RestSQLLexer.l.hpp and RestSQLLexer.l.cpp,
 * near the top.
 */
%top{
#include "RestSQLPreparer.hpp"
#define YYSTYPE RSQLP_STYPE
#define yy_accept rsqlp__accept
#define yy_base rsqlp__base
#define yy_chk rsqlp__chk
#define yy_def rsqlp__def
#define yy_ec rsqlp__ec
#define yy_meta rsqlp__meta
#define yy_nxt rsqlp__nxt
}

/*
 * This section will go into RestSQLLexer.l.cpp only, somewhere in the middle.
 */
%{
#include <stdio.h>
#include "RestSQLParser.y.hpp"
#define YY_DECL int yylex(RSQLP_STYPE* yylval_param, yyscan_t yyscanner)
#define punctuation(token) return T_ ## token
#define keyword(token) return T_ ## token
#define context yyextra
%}

/*
 * Start conditions other than INITAL. These are used to provide some (very
 * limited) context awareness in the lexer.
 */
%x QUOTED_IDENTIFIER

/* U_PARTIAL and U_OVERLONG are only used to detect UTF-8 decoding errors. */
U_2_PAR_1    (?# 110xxxxx                                             )[\300-\337]
U_3_PAR_1    (?# 1110xxxx                                             )[\340-\357]
U_3_PAR_2    (?# 1110xxxx 10xxxxxx                                    )[\340-\357][\200-\277]
U_4_PAR_1    (?# 11110xxx                                             )[\360-\367]
U_4_PAR_2    (?# 11110xxx 10xxxxxx                                    )[\360-\367][\200-\277]
U_4_PAR_3    (?# 11110xxx 10xxxxxx 10xxxxxx                           )[\360-\367][\200-\277][\200-\277]
U_PARTIAL    (?# An incomplete UTF-8 multi-byte sequence              ){U_2_PAR_1}|{U_3_PAR_1}|{U_3_PAR_2}|{U_4_PAR_1}|{U_4_PAR_2}|{U_4_PAR_3}
U_2_OVERLONG (?# 1100000x 10xxxxxx                                    )[\300\301][\200-\277]
U_3_OVERLONG (?# 11100000 100xxxxx 10xxxxxx                           )\340[\200-\237][\200-\277]
U_4_OVERLONG (?# 11110000 1000xxxx 10xxxxxx 10xxxxxx                  )\360[\200-\217][\200-\277]{2}
U_OVERLONG   (?# An overlong but otherwise correct UTF-8 character    ){U_2_OVERLONG}|{U_3_OVERLONG}|{U_4_OVERLONG}

/* U_EXTBMP and U_NONBMP are used to match correct UTF-8 characters. It's
 * tempting to match a simpler superset and use the error definitions above in a
 * higher-priority rule, but then it becomes problematic to use these
 * definitions in rules that match more than one character such as
 * {UNQUOTED_IDENTIFIER_CHARACTER}+ so the below definitions need to be correct
 * as they are, standalone. The difference operator {-} would have come in handy
 * but it unfortunately only works with character sets, not regular expressions.
 * Therefore, these definitions are a little involved.
 */
          // U+0080--U+07ff: 110NNNNx 10xxxxxx where NNNN != 0000
U_2          [\302-\337][\200-\277]
          // U+0800--U+d7ff: 1110NNNN 10Nxxxxx 10xxxxxx where 00001 <= NNNNN < 11011
U_3_LOW      (\340[\240-\277]|[\341-\354][\200-\277]|\355[\200-\237])[\200-\277]
          // U+d800--U+dfff: 11101101 101xxxxx 10xxxxxx
U_SURROGATE  \355[\240-\277][\200-\277]
          // U+e000--U+ffff: 1110111x 10xxxxxx 10xxxxxx
U_3_HIGH     [\356-\357][\200-\277]{2}
          // U+0080--U+d7ff, U+e000--U+ffff
U_EXTBMP     {U_2}|{U_3_LOW}|{U_3_HIGH}
          // U+010000--U+10ffff: 11110NNN 10NNxxxx 10xxxxxx 10xxxxxx where 00001 <= NNNNN <= 10000
U_4          (\360[\220-\277]|[\361-\363][\200-\277]|\364[\200-\217])[\200-\277]{2}
U_NONBMP     {U_4}

/* U_TOOHIGH and U_ILLEG_BYTE are only used to match UTF-8 decoding errors. */
          // U+110000--U+1fffff: 111101NN 10NNxxxx 10xxxxxx 10xxxxxx where NNNN!=0000
U_TOOHIGH    (\364[\220-\277]|[\365-\367][\200-\277])[\200-\277]{2}
          // 11111xxx
U_ILLEG_BYTE [\370-\377]

/*
 * Permitted characters in unquoted identifiers:
 * - ASCII: [0-9,a-z,A-Z$_] (basic Latin letters, digits 0-9, dollar,
 *   underscore)
 * - Extended: U+0080 .. U+FFFF
 * Permitted characters in quoted identifiers include the full Unicode Basic
 * Multilingual Plane (BMP), except U+0000:
 * - ASCII: U+0001 .. U+007F
 * - Extended: U+0080 .. U+FFFF
 * ASCII NUL (U+0000) and supplementary characters (U+10000 and higher) are not
 * permitted in quoted or unquoted identifiers.
 * See https://dev.mysql.com/doc/refman/8.0/en/identifiers.html
 */

UNQUOTED_IDENTIFIER_CHARACTER                                          [$0-9A-Z_a-z]|{U_EXTBMP}
QUOTED_IDENTIFIER_CHARACTER_EXCEPT_BACKTICK                            [^\0`\200-\377]|{U_EXTBMP}

/*
 * Double percent sign marking the begining (and end) of the lexical rules
 * section
 */
%%

 /* Top section for rules to catch errors */

<*>\0 {
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_NUL,
    yytext, 1);
  return T_ERR;
}

<*>{U_ILLEG_BYTE} {
  /*
   * Matches bytes 0xf8-0xff which are illegal in UTF-8. Technically, the same
   * applies to 0xc0-0xc1, but any presence of those bytes will be picked up by
   * U_OVERLONG or another error rule, potentially leading to slightly more
   * informative error messages.
   */
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_U_ILLEGAL_BYTE,
    yytext, 1);
  return T_ERR;
}

<*>{U_PARTIAL} {
  /*
   * A leading byte for a UTF-8 multi-byte sequence followed by too few
   * continuation bytes. Since this rule matches only sequences that are shorter
   * than correct sequences, it has lower priority and will therefore only match
   * a partial multi-byte sequence followed by an unexpected byte or <<EOF>>.
   */
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_U_ENC_ERR,
    yytext, 1);
  return T_ERR;
}

<*>[\200-\277] {
  // Rogue UTF-8 continuation byte
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_U_ENC_ERR,
    yytext, 1);
  return T_ERR;
}

<*>{U_OVERLONG} {
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_U_OVERLONG,
    yytext, 1);
  return T_ERR;
}

<*>{U_TOOHIGH} {
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_U_TOOHIGH,
    yytext, 1);
  return T_ERR;
}

<*>{U_SURROGATE} {
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_U_SURROGATE,
    yytext, 1);
  return T_ERR;
}

<INITIAL,QUOTED_IDENTIFIER>{U_NONBMP}(.|\n)* {
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_NONBMP_IDENTIFIER,
    yytext, 1);
  return T_ERR;
}

 /* Section for functionality (happy path) rules */

"+" punctuation(PLUS);
"-" punctuation(MINUS);
"*" punctuation(MULTIPLY);
"/" punctuation(DIVIDE);
"%" punctuation(MODULO);
"(" punctuation(LEFT);
")" punctuation(RIGHT);
"," punctuation(COMMA);
";" punctuation(SEMICOLON);

by      keyword(BY);
count   keyword(COUNT);
from    keyword(FROM);
group   keyword(GROUP);
max     keyword(MAX);
min     keyword(MIN);
select  keyword(SELECT);
sum     keyword(SUM);

[ \t\r\n] ; // ignore whitespace

[0-9]+\.[0-9]+ {
  yylval->fval = atof(yytext);
  return T_FLOAT;
}

[0-9]+ {
  yylval->ival = atoi(yytext);
  return T_INT;
}

{UNQUOTED_IDENTIFIER_CHARACTER}+ {
 /*
  * This regex will match not only identifiers, but also keywords. Terminating
  * or delimiting tokens by whitespace is not part of the lexer rules, so one
  * could believe that something like "selectblabla" could be interpreted as the
  * SELECT keyword followed by an identifier "blabla". This ambiguity is
  * resolved since flex prioritizes the rule with the longest match, so in this
  * case the whole of "selectblabla" will be interpreted as an identifier. Now,
  * the keyword "select" by itself also matches this rule. In the case of two
  * rules matching with equal length, flex selects the one mentioned first. So,
  * since the keywords are defined first, they take precedence.
  */
  yylval->str = LexString{yytext, size_t(yyleng)};
  return T_IDENTIFIER;
}

` {
  BEGIN(QUOTED_IDENTIFIER);
  yylval->str = LexString{ NULL, 0};
  context->m_compound_token_pos = yytext;
  context->m_compound_token_len = 0;
}
<QUOTED_IDENTIFIER>{QUOTED_IDENTIFIER_CHARACTER_EXCEPT_BACKTICK}+ {
    yylval->str = yylval->str.concat(LexString{ yytext, size_t(yyleng) },
                                     context->get_allocator());
}
<QUOTED_IDENTIFIER>`` {
  yylval->str = yylval->str.concat(LexString{ yytext, 1 }, context->get_allocator());
}
<QUOTED_IDENTIFIER>` {
  context->m_compound_token_len = yytext + 1 - context->m_compound_token_pos;
  BEGIN(INITIAL);
  return T_IDENTIFIER;
}
<QUOTED_IDENTIFIER><<EOF>> {
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_UNEXPECTED_EOF_IN_QUOTED_IDENTIFIER,
    context->m_compound_token_pos,
    yytext - context->m_compound_token_pos);
  return T_ERR;
}

 /* Bottom section for rules to catch errors */

[\001-\010\013\014\016-\037\041-\043\046\047\056\072\074-\100\133-\137\173-\177] {
  /*
   * We have no default rule. Instead, this rule is carefully maintained to
   * catch anything that other rules won't. This is mostly for documentation
   * purposes. If this rule catches too little, flex will warn and our makefile
   * will treat that warning as an error. If it catches too much, the fact that
   * it is placed last and only matches one byte will put it strictly lowest in
   * priority, so flex will automatically shrink the scope appropriately.
   */
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_ILLEGAL_TOKEN,
    yytext, 1);
  return T_ERR;
}

%%

void*
rsqlp_alloc(size_t bytes, void * scanner)
{
  return rsqlp_get_extra(scanner)->get_allocator()->alloc(bytes);
}

void*
rsqlp_realloc(void * ptr, size_t bytes, void * scanner)
{
  // If realloc is needed, we need to keep track of allocation size.
  abort();
}

void
rsqlp_free(void * ptr, void * scanner)
{}
