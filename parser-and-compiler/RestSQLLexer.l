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
#define keyword(token) return T_ ## token;
#define pos_keyword(token) do { \
  yylval->pos_keyword.type = T_ ## token; \
  yylval->pos_keyword.begin = yytext; \
  return T_ ## token; \
} while(0)
#define context yyextra
%}

/*
 * Start conditions other than INITAL. These are used to provide some (very
 * limited) context awareness in the lexer.
 */
%x QUOTED_IDENTIFIER
%x SINGLE_QUOTED_STRING

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
SINGLE_QUOTED_STRING_CHARACTER_EXCEPT_APOSTROPHE_AND_BACKSLASH         [^\0\047\134\200-\377]|{U_EXTBMP}|{U_NONBMP}

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
  // todo: is (.|\n)* necessary above?
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_NONBMP_IDENTIFIER,
    yytext, 1);
  return T_ERR;
}

 /* Section for functionality (happy path) rules */

 /* Operators, strongest binding last */
"or"|"||"  keyword(OR);
"xor"      keyword(XOR);
"and"|"&&" keyword(AND);
"not"      keyword(NOT);
"="        keyword(EQUALS);
">="       keyword(GE);
">"        keyword(GT);
"<="       keyword(LE);
"<"        keyword(LT);
"<>"|"!="  keyword(NOT_EQUALS);
"is"       keyword(IS);
"|"        keyword(BITWISE_OR);
"&"        keyword(BITWISE_AND);
"<<"       keyword(BITSHIFT_LEFT);
">>"       keyword(BITSHIFT_RIGHT);
"+"        keyword(PLUS);
"-"        keyword(MINUS);
"*"        keyword(MULTIPLY);
"/"        keyword(DIVIDE);
"%"        keyword(MODULO);
"^"        keyword(BITWISE_XOR);
"!"        keyword(EXCLAMATION);
"interval" keyword(INTERVAL);

 /* Non-operator keywords */
"("     keyword(LEFT);
")"     pos_keyword(RIGHT);
","     keyword(COMMA);
";" keyword(SEMICOLON);
as      keyword(AS);
avg     pos_keyword(AVG);
by      keyword(BY);
count   pos_keyword(COUNT);
from    keyword(FROM);
group   keyword(GROUP);
max     pos_keyword(MAX);
min     pos_keyword(MIN);
null    keyword(NULL);
select  keyword(SELECT);
sum     pos_keyword(SUM);
where   keyword(WHERE);

[ \t\r\n] ; // ignore whitespace

[0-9]+\.[0-9]+ {
  yylval->fval = atof(yytext);
  return T_FLOAT;
}

[0-9]+ {
  yylval->ival = atoi(yytext);
  return T_INT;
}

accessible|account|action|active|add|admin|after|against|aggregate|algorithm|all|alter|always|analyse|analyze|and|any|array|as|asc|ascii|asensitive|at|attribute|authentication|auto_increment|autoextend_size|avg|avg_row_length|backup|before|begin|between|bigint|binary|binlog|bit|blob|block|bool|boolean|both|btree|buckets|bulk|by|byte|cache|call|cascade|cascaded|case|catalog_name|chain|challenge_response|change|changed|channel|char|character|charset|check|checksum|cipher|class_origin|client|clone|close|coalesce|code|collate|collation|column|column_format|column_name|columns|comment|commit|committed|compact|completion|component|compressed|compression|concurrent|condition|connection|consistent|constraint|constraint_catalog|constraint_name|constraint_schema|contains|context|continue|convert|cpu|create|cross|cube|cume_dist|current|current_date|current_time|current_timestamp|current_user|cursor|cursor_name|data|database|databases|datafile|date|datetime|day|day_hour|day_microsecond|day_minute|day_second|deallocate|dec|decimal|declare|default|default_auth|definer|definition|delay_key_write|delayed|delete|dense_rank|des_key_file|desc|describe|description|deterministic|diagnostics|directory|disable|discard|disk|distinct|distinctrow|div|do|double|drop|dual|dumpfile|duplicate|dynamic|each|else|elseif|empty|enable|enclosed|encryption|end|ends|enforced|engine|engine_attribute|engines|enum|error|errors|escape|escaped|event|events|every|except|exchange|exclude|execute|exists|exit|expansion|expire|explain|export|extended|extent_size|factor|failed_login_attempts|false|fast|faults|fetch|fields|file|file_block_size|filter|finish|first|first_value|fixed|float|float4|float8|flush|following|follows|for|force|foreign|format|found|from|full|fulltext|function|general|generate|generated|geomcollection|geometry|geometrycollection|get|get_format|get_master_public_key|get_source_public_key|global|grant|grants|group|group_replication|grouping|groups|gtid_only|handler|hash|having|help|high_priority|histogram|history|host|hosts|hour|hour_microsecond|hour_minute|hour_second|identified|if|ignore|ignore_server_ids|import|in|inactive|index|indexes|infile|initial|initial_size|initiate|inner|inout|insensitive|insert|insert_method|install|instance|int|int1|int2|int3|int4|int8|integer|intersect|interval|into|invisible|invoker|io|io_after_gtids|io_before_gtids|io_thread|ipc|is|isolation|issuer|iterate|join|json|json_table|json_value|key|key_block_size|keyring|keys|kill|lag|language|last|last_value|lateral|lead|leading|leave|leaves|left|less|level|like|limit|linear|lines|linestring|list|load|local|localtime|localtimestamp|lock|locked|locks|logfile|logs|long|longblob|longtext|loop|low_priority|master|master_auto_position|master_bind|master_compression_algorithms|master_connect_retry|master_delay|master_heartbeat_period|master_host|master_log_file|master_log_pos|master_password|master_port|master_public_key_path|master_retry_count|master_server_id|master_ssl|master_ssl_ca|master_ssl_capath|master_ssl_cert|master_ssl_cipher|master_ssl_crl|master_ssl_crlpath|master_ssl_key|master_ssl_verify_server_cert|master_tls_ciphersuites|master_tls_version|master_user|master_zstd_compression_level|match|max_connections_per_hour|max_queries_per_hour|max_rows|max_size|max_updates_per_hour|max_user_connections|maxvalue|medium|mediumblob|mediumint|mediumtext|member|memory|merge|message_text|microsecond|middleint|migrate|min_rows|minute|minute_microsecond|minute_second|mod|mode|modifies|modify|month|multilinestring|multipoint|multipolygon|mutex|mysql_errno|name|names|national|natural|nchar|ndb|ndbcluster|nested|network_namespace|never|new|next|no|no_wait|no_write_to_binlog|nodegroup|none|not|nowait|nth_value|ntile|null|nulls|number|numeric|nvarchar|of|off|offset|oj|old|on|one|only|open|optimize|optimizer_costs|option|optional|optionally|options|or|order|ordinality|organization|others|out|outer|outfile|over|owner|pack_keys|page|parse_gcol_expr|parser|partial|partition|partitioning|partitions|password|password_lock_time|path|percent_rank|persist|persist_only|phase|plugin|plugin_dir|plugins|point|polygon|port|precedes|preceding|precision|prepare|preserve|prev|primary|privilege_checks_user|privileges|procedure|process|processlist|profile|profiles|proxy|purge|quarter|query|quick|random|range|rank|read|read_only|read_write|reads|real|rebuild|recover|recursive|redo_buffer_size|redofile|redundant|reference|references|regexp|registration|relay|relay_log_file|relay_log_pos|relay_thread|relaylog|release|reload|remote|remove|rename|reorganize|repair|repeat|repeatable|replace|replica|replicas|replicate_do_db|replicate_do_table|replicate_ignore_db|replicate_ignore_table|replicate_rewrite_db|replicate_wild_do_table|replicate_wild_ignore_table|replication|require|require_row_format|reset|resignal|resource|respect|restart|restore|restrict|resume|retain|return|returned_sqlstate|returning|returns|reuse|reverse|revoke|right|rlike|role|rollback|rollup|rotate|routine|row|row_count|row_format|row_number|rows|rtree|savepoint|schedule|schema|schema_name|schemas|second|second_microsecond|secondary|secondary_engine|secondary_engine_attribute|secondary_load|secondary_unload|security|select|sensitive|separator|serial|serializable|server|session|set|share|show|shutdown|signal|signed|simple|skip|slave|slow|smallint|snapshot|socket|some|soname|sounds|source|source_auto_position|source_bind|source_compression_algorithms|source_connect_retry|source_delay|source_heartbeat_period|source_host|source_log_file|source_log_pos|source_password|source_port|source_public_key_path|source_retry_count|source_ssl|source_ssl_ca|source_ssl_capath|source_ssl_cert|source_ssl_cipher|source_ssl_crl|source_ssl_crlpath|source_ssl_key|source_ssl_verify_server_cert|source_tls_ciphersuites|source_tls_version|source_user|source_zstd_compression_level|spatial|specific|sql|sql_after_gtids|sql_after_mts_gaps|sql_before_gtids|sql_big_result|sql_buffer_result|sql_cache|sql_calc_found_rows|sql_no_cache|sql_small_result|sql_thread|sql_tsi_day|sql_tsi_hour|sql_tsi_minute|sql_tsi_month|sql_tsi_quarter|sql_tsi_second|sql_tsi_week|sql_tsi_year|sqlexception|sqlstate|sqlwarning|srid|ssl|stacked|start|starting|starts|stats_auto_recalc|stats_persistent|stats_sample_pages|status|stop|storage|stored|straight_join|stream|string|subclass_origin|subject|subpartition|subpartitions|super|suspend|swaps|switches|system|table|table_checksum|table_name|tables|tablespace|temporary|temptable|terminated|text|than|then|thread_priority|ties|time|timestamp|timestampadd|timestampdiff|tinyblob|tinyint|tinytext|tls|to|trailing|transaction|trigger|triggers|true|truncate|type|types|unbounded|uncommitted|undefined|undo|undo_buffer_size|undofile|unicode|uninstall|union|unique|unknown|unlock|unregister|unsigned|until|update|upgrade|url|usage|use|use_frm|user|user_resources|using|utc_date|utc_time|utc_timestamp|validation|value|values|varbinary|varchar|varcharacter|variables|varying|vcpu|view|virtual|visible|wait|warnings|week|weight_string|when|where|while|window|with|without|work|wrapper|write|x509|xa|xid|xml|xor|year|year_month|zerofill|zone {
 /*
  * This regex will match any keyword in MySQL 8.0 and 5.7. Since the keywords
  * we implement are matched by earlier rules, and identifiers are matched by a
  * later rule, this rule will match keywords that we have not implemented. The
  * reason we want to throw an error at the mention of an unimplemented keyword,
  * is that we might want to implement it in the future, at which point such
  * keyword might not be valid as an unquoted identifier. For the sake of
  * backward compatibility, we'd like such identifiers to be invalid even before
  * the keyword is implemented. Note that MySQL differs between reserved and
  * non-reserved keyword, where only reserved keywords are invalid as unquoted
  * identifiers. For the sake of simplicity, we make no such distinction for
  * RonDB REST SQL, and instead disallow the use of all keywords - both reserved
  * and not, both implemented and not - as unquoted identifiers.
  * todo: Decide whether to disallow unquoted identifiers altogether.
  * todo: This rule quadruples the size of RestSQLLexer.l.cpp. Is it better to hand-code keyword detection?
  */
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_UNIMPLEMENTED_KEYWORD,
    yytext, yyleng);
  return T_ERR;
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

 /*
  * Single-quoted strings implemented according to
  * https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
  *
  * \047 is apostrophe ('), \134 is backslash (\)
  */
\047 {
  BEGIN(SINGLE_QUOTED_STRING);
  yylval->str = LexString{ NULL, 0};
  context->m_compound_token_pos = yytext;
  context->m_compound_token_len = 0;
}
<SINGLE_QUOTED_STRING>{SINGLE_QUOTED_STRING_CHARACTER_EXCEPT_APOSTROPHE_AND_BACKSLASH}+ {
  yylval->str = yylval->str.concat(LexString{ yytext, size_t(yyleng) },
                                   context->get_allocator());
}
<SINGLE_QUOTED_STRING>\047\047 {
  yylval->str = yylval->str.concat(LexString{ yytext, 1 },
                                   context->get_allocator());
}
<SINGLE_QUOTED_STRING>\047 {
  context->m_compound_token_len = yytext + 1 - context->m_compound_token_pos;
  BEGIN(INITIAL);
  return T_STRING;
}
<SINGLE_QUOTED_STRING>\134. {
  char escchar = yytext[1];
  LexString result = { NULL, 0};
  switch (escchar)
  {
  case '0':
    result = { "\0", 1 };
    break;
  case '\'':
    result = { "\'", 1 };
     break;
  case '"':
    result = { "\"", 1 };
    break;
  case 'b':
    result = { "\b", 1 };
    break;
  case 'n':
    result = { "\n", 1 };
    break;
  case 'r':
    result = { "\r", 1 };
    break;
  case 't':
    result = { "\t", 1 };
    break;
  case 'Z':
    result = { "\032", 1 };
    break;
  case '\\':
    result = { "\\", 1 };
    break;
  case '%':
    result = { "\\%", 2 };
    break;
  case '_':
    result = { "\\_", 2 };
    break;
  default:
    result = { &yytext[1], 1 };
    break;
  }
  yylval->str = yylval->str.concat(result, context->get_allocator());
}
<SINGLE_QUOTED_STRING>\134 {
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_INCOMPLETE_ESCAPE_SEQUENCE_IN_SINGLE_QUOTED_STRING,
    yytext, 1);
  return T_ERR;
}
<SINGLE_QUOTED_STRING><<EOF>> {
  context->set_err_state(
    RestSQLPreparer::ErrState::LEX_UNEXPECTED_EOF_IN_SINGLE_QUOTED_STRING,
    context->m_compound_token_pos,
    yytext - context->m_compound_token_pos);
  return T_ERR;
}
<SINGLE_QUOTED_STRING>\047[ \t\r\n]+\047 {
  // Quoted strings placed next to each other are concatenated to a single string.
}

 /* Bottom section for rules to catch errors */

[\001-\010\013\014\016-\037\042\043\056\072\077-\100\133-\135\137\173\175-\177] {
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
