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

#include <assert.h>
#include "AggregationAPICompiler.hpp"
#include "RestSQLParser.y.hpp"
#include "RestSQLLexer.l.hpp"
#include "RestSQLPreparer.hpp"
using std::cout;
using std::cerr;
using std::endl;

RestSQLPreparer::RestSQLPreparer(LexString modifiable_SQL,
                                 ArenaAllocator* aalloc):
  m_identifiers(aalloc),
  m_aalloc(aalloc),
  m_context(*this)
{
  /*
   * Both `yy_scan_string' and `yy_scan_bytes' create and scan a copy of the
   * input. This may be desirable, since `yylex()' modifies the contents of the
   * buffer it is scanning. In order to avoid copying, we use `yy_scan_buffer'.
   * It requires the last two bytes of the buffer to be NUL. These last two
   * bytes are not scanned.
   * See https://ftp.gnu.org/old-gnu/Manuals/flex-2.5.4/html_node/flex_12.html
   */
  char* buffer = modifiable_SQL.str;
  uint flex_buffer_len = modifiable_SQL.len;
  assert(buffer[flex_buffer_len-1] == '\0');
  assert(buffer[flex_buffer_len-2] == '\0');
  rsqlp_lex_init_extra(&m_context, &m_scanner);
  m_buf = rsqlp__scan_buffer(buffer, flex_buffer_len, m_scanner);
  // We don't want the NUL bytes that flex requires.
  uint our_buffer_len = flex_buffer_len - 2;
  m_sql = { buffer, our_buffer_len };
}

#define assert_status(name) assert(m_status == Status::name)

bool
RestSQLPreparer::parse()
{
  if (m_status == Status::FAILED)
  {
    return false;
  }
  assert_status(INITIALIZED);
  m_status = Status::PARSING;
  int parse_result = rsqlp_parse(m_scanner);
  if (parse_result == 0)
  {
    assert(m_context.m_err_state == ErrState::NONE);
    m_status = Status::PARSED;
    return true;
  }
  m_status = Status::FAILED;
  // The rest is error handling.
  if (parse_result == 2)
  {
    // Parser reports OOM, which shouldn't happen since our allocator throws an
    // exception on OOM.
    cerr << "Out of memory during parsing" << endl;
    m_status = Status::FAILED;
    return false;
  }
  assert(parse_result == 1);
  assert(m_context.m_err_state != ErrState::NONE);
  assert(m_sql.str <= m_context.m_err_pos);
  uint err_pos = m_context.m_err_pos - m_sql.str;
  uint err_stop = err_pos + m_context.m_err_len;
  assert(err_pos <= m_sql.len);
  assert(err_stop <= m_sql.len + 1); // "Unexpected end of input" marks the
                                     // character directly after the end.
  const char* msg = NULL;
  bool print_statement = true;
  switch (m_context.m_err_state)
  {
  case ErrState::LEX_NUL:
    msg = "Unexpected null byte.";
    break;
  case ErrState::LEX_U_ILLEGAL_BYTE:
    msg = "Bytes 0xf8-0xff are illegal in UTF-8.";
    break;
  case ErrState::LEX_U_OVERLONG:
    msg = "Overlong UTF-8 encoding.";
    break;
  case ErrState::LEX_U_TOOHIGH:
    msg = "Unicode code points above U+10FFFF are invalid.";
    break;
  case ErrState::LEX_U_SURROGATE:
    msg = "Unicode code points U+D800 -- U+DFFF are invalid, as they correspond to UTF-16 surrogate pairs.";
    break;
  case ErrState::LEX_NONBMP_IDENTIFIER:
    msg = "Unicode code points above U+FFFF are not allowed in MySQL identifiers.";
    break;
  case ErrState::LEX_ILLEGAL_TOKEN:
    msg = "Illegal token";
    break;
  case ErrState::LEX_UNEXPECTED_EOF_IN_QUOTED_IDENTIFIER:
    msg = "Unexpected end of input inside quoted identifier";
    break;
  case ErrState::LEX_U_ENC_ERR:
    msg = "Invalid UTF-8 encoding.";
    break;
  case ErrState::PARSER_ERROR:
    if (m_sql.len == 0)
    {
      fprintf(stderr, "Syntax error in SQL statement: Empty input\n");
      print_statement = false;
    }
    else if (err_pos == m_sql.len)
    {
      msg = "Unexpected end of input";
    }
    else
    {
      msg = "Unexpected at this point";
    }
    break;
  default:
    abort();
  }
  if (print_statement)
  {
    /*
     * Explain the syntax error by showing the message followed by a print of
     * the SQL statement with the problematic section underlined with carets.
     */
    restoreOriginalBuffer();
    cerr << "Syntax error in SQL statement: " << msg << endl;
    uint line_started_at = 0;
    for (uint pos = 0; pos <= m_sql.len; pos++)
    {
      if (line_started_at == pos)
      {
        cerr << "> ";
      }
      char c = m_sql.str[pos];
      bool is_eol = c == '\n';
      if (pos == m_sql.len)
      {
        if (m_sql.str[pos-1] != '\n')
        {
          cerr << '\n';
          is_eol = true;
        }
      }
      else if ( c != '\r')
      {
        cerr << c;
      }
      if (is_eol &&
         err_pos <= pos &&
         line_started_at <= err_stop)
      {
        cerr << "! ";
        uint err_marker_pos = line_started_at;
        while (err_marker_pos < err_pos)
        {
          if (has_width(err_marker_pos))
          {
            cerr << " ";
          }
          err_marker_pos++;
        }
        while (err_marker_pos < err_stop &&
              (pos == err_pos
               ? err_marker_pos <= pos
               : err_marker_pos < pos))
        {
          if (has_width(err_marker_pos))
          {
            cerr << "^";
          }
          err_marker_pos++;
        }
        cerr << endl;
      }
      if (is_eol)
      {
        line_started_at = pos + 1;
      }
    }
  }
  return false;
}

bool
RestSQLPreparer::has_width(uint pos)
{
  // Return false if the position is a UTF-8 continuation byte and part of a
  // prefix of a correct UTF-8 multi-byte sequence, otherwise true.
  char* s = m_sql.str;
  char c = s[pos];
  if ((c & 0xc0) != 0x80) return true;
  if (pos < 1) return true;
  c = s[pos - 1];
  if ((c & 0xe0) == 0xc0) return false;
  if ((c & 0xf0) == 0xe0) return false;
  if ((c & 0xf8) == 0xf0) return false;
  if ((c & 0xc0) != 0x80) return true;
  if (pos < 2) return true;
  c = s[pos - 2];
  if ((c & 0xf0) == 0xe0) return false;
  if ((c & 0xf8) == 0xf0) return false;
  if ((c & 0xc0) != 0x80) return true;
  if (pos < 3) return true;
  c = s[pos - 3];
  if ((c & 0xf8) == 0xf0) return false;
  return true;
}

bool
RestSQLPreparer::load()
{
  if (m_status == Status::FAILED)
  {
    return false;
  }
  assert_status(PARSED);
  m_status = Status::LOADING;
  /*
   * todo: During parsing, strings that are claimed to be column names were
   * assigned consecutive indexes as they were found. These indexes have already
   * been used to construct expressions in m_agg. Now that parsing is done and
   * we know the table name, we should look up the real column indexes in the
   * schema, check that the table and columns exist, and remap the indexes
   * inside both m_ast_root and m_agg.
   */

  // Load schema information and check that the table and columns exist.

  // Remap column indexes in m_ast_root and m_agg.

  // Load aggregates
  Outputs* outputs = m_context.ast_root.outputs;
  while (outputs != NULL)
  {
    if (outputs->is_agg)
    {
      assert(m_agg != NULL);
      int fun = outputs->aggregate.fun;
      AggregationAPICompiler::Expr* expr = outputs->aggregate.arg;
      switch (fun)
      {
      case T_COUNT:
        m_agg->Count(expr);
        break;
      case T_MAX:
        m_agg->Max(expr);
        break;
      case T_MIN:
        m_agg->Min(expr);
        break;
      case T_SUM:
        m_agg->Sum(expr);
        break;
      default:
        assert(false);
      }
    }
    outputs = outputs->next;
  }
  if (m_agg != NULL)
  {
    if (m_agg->getStatus() != AggregationAPICompiler::Status::PROGRAMMING)
    {
      m_status = Status::FAILED;
      return false;
    }
  }
  m_status = Status::LOADED;
  return true;
}

bool
RestSQLPreparer::compile()
{
  if (m_status == Status::FAILED)
  {
    return false;
  }
  assert_status(LOADED);
  m_status = Status::COMPILING;
  if (m_agg != NULL)
  {
    if (m_agg->compile())
    {
      assert(m_agg->getStatus() == AggregationAPICompiler::Status::COMPILED);
      m_status = Status::COMPILED;
      return true;
    }
    else
    {
      assert(m_agg->getStatus() == AggregationAPICompiler::Status::FAILED);
      m_status = Status::FAILED;
      return false;
    }
  }
  m_status = Status::COMPILED;
  return true;
}

bool
RestSQLPreparer::print()
{
  if (m_status == Status::FAILED)
  {
    return false;
  }
  assert_status(COMPILED);
  SelectStatement& ast_root = m_context.ast_root;
  cout << "SELECT\n";
  Outputs* outputs = ast_root.outputs;
  int out_count = 0;
  int col_count = 0;
  int agg_count = 0;
  while (outputs != NULL)
  {
    cout << "  Out_" << out_count << "=";
    if (outputs->is_agg)
    {
      cout << "A" << agg_count << ":";
      m_agg->print_aggregate(agg_count);
      cout << endl;
      agg_count++;
    }
    else
    {
      auto col_name = outputs->col_name;
      auto col_idx = column_name_to_idx(col_name);
      cout << "C" << col_idx << ":";
      m_agg->print_quoted_identifier(col_name);
      cout << endl;
      col_count++;
    }
    out_count++;
    outputs = outputs->next;
  }
  cout << "FROM " << ast_root.table << endl;
  struct GroupbyColumns* groupby = ast_root.groupby_columns;
  if (groupby != NULL)
  {
    cout << "GROUP BY" << endl;
    while (groupby != NULL)
    {
      auto col_name = groupby->col_name;
      auto col_idx = column_name_to_idx(col_name);
      cout << "  C" << col_idx << ":" << col_name << endl;
      groupby = groupby->next;
    }
  }
  cout << endl;
  if (m_agg != NULL)
  {
    m_agg->print_program();
  }
  else
  {
    printf("No aggregation program.\n\n");
  }
  return true;
}

/*
 * This function uses an undo log to restore the buffer to its original state.
 * This is useful when we have a parse error and need the original SQL to
 * describe the error. For performance reasons we don't want to keep a copy
 * around. The undo log itself has little performance impact since it is very
 * seldom used.
 */
void
RestSQLPreparer::restoreOriginalBuffer()
{
  // Restoring the buffer can alter the contents of some LexString objects that
  // are needed during loading, so make sure we're in a failed state.
  assert_status(FAILED);
  DynamicArray<Undo>& undos = m_context.m_undo;
  for (int i=0; i < undos.size(); i++)
  {
    Undo& undo = undos[undos.size()-i-1]; // reverse order
    memmove(undo.src, undo.dest, undo.len); // reverse move
  }
  // Truncate undo log to prevent double undo
  m_context.m_undo.truncate();
  assert(m_context.m_undo.size() == 0);
}

int
RestSQLPreparer::column_name_to_idx(LexString col_name)
{
  for (int i=0; i<m_identifiers.size(); i++)
  {
    if (m_identifiers[i] == col_name)
    {
      return i;
    }
  }
  m_identifiers.push(col_name);
  return m_identifiers.size()-1;
}

LexString
RestSQLPreparer::column_idx_to_name(int col_idx)
{
  assert(col_idx < m_identifiers.size());
  return m_identifiers[col_idx];
}

RestSQLPreparer::~RestSQLPreparer()
{
  rsqlp__delete_buffer(m_buf, m_scanner);
  rsqlp_lex_destroy(m_scanner);
}

void
RestSQLPreparer::Context::set_err_state(ErrState state,
                                  char* err_pos,
                                  uint err_len)
{
  if (m_err_state == ErrState::NONE)
  {
    m_err_state = state;
    m_err_pos = err_pos;
    m_err_len = err_len;
  }
}

AggregationAPICompiler*
RestSQLPreparer::Context::get_agg()
{
  if (m_parser.m_agg)
  {
    return m_parser.m_agg;
  }
  RestSQLPreparer* _this = &m_parser;
  std::function<int(LexString)> column_name_to_idx =
    [_this](LexString ls) -> int
    {
      for (int i=0; i<_this->m_identifiers.size(); i++)
      {
        if (ls == LexString(_this->m_identifiers[i]))
        {
          return i;
        }
      }
      _this->m_identifiers.push(ls);
      return _this->m_identifiers.size()-1;
    };
  std::function<LexString(int)> column_idx_to_name =
    [_this](int idx) -> LexString
    {
      assert(idx >= 0 && idx < _this->m_identifiers.size());
      return _this->m_identifiers[idx];
    };

  /*
   * The aggregator uses the same arena allocator as the RestSQLPreparer object
   * because they are both working in the prepare phase. After loading and
   * compilation, a new object will be crafted that holds the information
   * necessary for execution and post-processing.
   */
  m_parser.m_agg = new AggregationAPICompiler(column_name_to_idx,
                                  column_idx_to_name,
                                  m_parser.m_aalloc);
  return m_parser.m_agg;
}

void*
RestSQLPreparer::Context::alloc(size_t size)
{
  return m_parser.m_aalloc->alloc(size);
}
