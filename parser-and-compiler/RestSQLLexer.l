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

/*
 * Double percent sign marking the begining (and end) of the lexical rules
 * section
 */
%%

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

[\0\001\002\003\004\005\006\007\010\013\014\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037\177](.|\n)* {
  /*
   * This is the illegal character rule, used to guard against some control
   * characters. The rule is first and match all remaining text in order to have
   * the highest priority. This still does not guarantee protection against
   * illegal characters. We must also make sure that 1) No other rule can match
   * a control character later in input, and 2) A similar rule exists for every
   * start condition. Illegal characters are:
   * Hex  Oct Name
   * 0x00 000 NUL
   * 0x01 001 SOH
   * 0x02 002 STX
   * 0x03 003 ETX
   * 0x04 004 EOT
   * 0x05 005 ENQ
   * 0x06 006 ACK
   * 0x07 007 BEL
   * 0x08 010 BS
   * 0x0B 013 VT
   * 0x0C 014 FF
   * 0x0E 016 SO
   * 0x0F 017 SI
   * 0x10 020 DLE
   * 0x11 021 DC1
   * 0x12 022 DC2
   * 0x13 023 DC3
   * 0x14 024 DC4
   * 0x15 025 NAK
   * 0x16 026 SYN
   * 0x17 027 ETB
   * 0x18 030 CAN
   * 0x19 031 EM
   * 0x1A 032 SUB
   * 0x1B 033 ESC
   * 0x1C 034 FS
   * 0x1D 035 GS
   * 0x1E 036 RS
   * 0x1F 037 US
   * 0x7F 177 DEL
   */
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_ILLEGAL_CHARACTER,
    yytext, 1);
  return T_ERR;
}

[ \t\r\n] ; // ignore whitespace

[0-9]+\.[0-9]+ {
  yylval->fval = atof(yytext);
  return T_FLOAT;
}

[0-9]+ {
  yylval->ival = atoi(yytext);
  return T_INT;
}

[a-z_][a-z0-9_]* {
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
  yylval->str.str = &yytext[1];
  yylval->str.len = 0;
}
<QUOTED_IDENTIFIER>[\0\001\002\003\004\005\006\007\010\013\014\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037\177](.|\n)* {
  /*
   * Illegal character rule for the QUOTED_IDENTIFIER start condition.
   */
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_ILLEGAL_CHARACTER,
    yytext, 1);
  return T_ERR;
}
<QUOTED_IDENTIFIER>[^`\0\001\002\003\004\005\006\007\010\013\014\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037\177]+ {
  char* dest = yylval->str.str + yylval->str.len;
  if(dest != yytext)
  {
    memmove(dest, yytext, yyleng);
    context->m_undo.push(RestSQLPreparer::Undo{dest, yytext, yyleng});
  }
  yylval->str.len += yyleng;
}
<QUOTED_IDENTIFIER>`` {
  char* dest = yylval->str.str + yylval->str.len;
  if(dest != yytext)
  {
    yylval->str.str[yylval->str.len] = '`';
    context->m_undo.push(RestSQLPreparer::Undo{dest, yytext, 1});
  }
  context->m_undo.push(RestSQLPreparer::Undo{dest, yytext + 1, 1});
  yylval->str.len++;
}
<QUOTED_IDENTIFIER>` {
  context->m_compound_token_pos = yylval->str.str - 1;
  context->m_compound_token_len = yytext + 1 - context->m_compound_token_pos;
  BEGIN(INITIAL);
  return T_IDENTIFIER;
}
<QUOTED_IDENTIFIER><<EOF>> {
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_UNEXPECTED_EOF_IN_QUOTED_IDENTIFIER,
    yylval->str.str - 1,
    yytext - yylval->str.str + 1);
  return T_ERR;
}

. {
  /*
   * This is the default rule. It is defined last in order to have lowest
   * priority. It matches any character except newline.
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
  return rsqlp_get_extra(scanner)->alloc(bytes);
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
