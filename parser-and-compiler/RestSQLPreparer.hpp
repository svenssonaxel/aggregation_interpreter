#ifndef RestSQLPreparer_hpp_included
#define RestSQLPreparer_hpp_included 1

#include <cstddef>
#include <cstdint>
#include "AggregationAPICompiler.hpp"
#include "LexString.hpp"
#include "ArenaAllocator.hpp"
#include "DynamicArray.hpp"

// Definitions from RestSQLLexer.l.hpp that are needed here. We can't include
// the whole file because it would create a circular dependency.
typedef void* yyscan_t;
typedef struct yy_buffer_state *YY_BUFFER_STATE;
struct yy_buffer_state;

struct Outputs
{
  bool is_agg;
  union
  {
    LexString col_name;
    struct
    {
      int fun;
      AggregationAPICompiler::Expr* arg;
    } aggregate;
  };
  struct Outputs* next;
};

struct GroupbyColumns
{
  LexString col_name;
  struct GroupbyColumns* next;
};

struct SelectStatement
{
  Outputs* outputs = NULL;
  LexString table = {NULL, 0};
  struct GroupbyColumns* groupby_columns = NULL;
};

class RestSQLPreparer
{
public:
  enum class ErrState
  {
    NONE,
    LEX_ILLEGAL_CHARACTER,
    LEX_ILLEGAL_TOKEN,
    LEX_UNEXPECTED_EOF_IN_QUOTED_IDENTIFIER,
    PARSER_ERROR,
  };
  struct Undo
  {
    // See comment for RestSQLPreparer::restoreOriginalBuffer
    char* dest;
    char* src;
    int len;
  };
  /*
   * The context class is used to expose parser internals to flex and bison code
   * without making them public.
   */
  class Context
  {
    friend class RestSQLPreparer;
  private:
    RestSQLPreparer& m_parser;
    ErrState m_err_state = ErrState::NONE;
    char* m_err_pos = NULL;
    uint m_err_len = 0;
  public:
    Context(RestSQLPreparer& parser):
      m_parser(parser),
      m_undo(parser.m_aalloc)
    {}
    void set_err_state(ErrState state, char* err_pos, uint err_len);
    AggregationAPICompiler* get_agg();
    void* alloc(size_t size);
    SelectStatement ast_root;
    char* m_compound_token_pos = NULL;
    uint m_compound_token_len = 0;
    DynamicArray<Undo> m_undo;
  };
private:
  enum class Status
  {
    INITIALIZED,
    PARSING,
    PARSED,
    LOADING,
    LOADED,
    COMPILING,
    COMPILED,
    FAILED,
  };
  Status m_status = Status::INITIALIZED;
  LexString m_sql = {NULL, 0};
  ArenaAllocator* m_aalloc;
  Context m_context;
  DynamicArray<LexString> m_identifiers;
  yyscan_t m_scanner;
  YY_BUFFER_STATE m_buf;
  AggregationAPICompiler* m_agg = NULL;
  int column_name_to_idx(LexString);
  LexString column_idx_to_name(int);
  void restoreOriginalBuffer();

public:
  RestSQLPreparer(LexString modifiable_SQL, ArenaAllocator* aalloc);
  bool parse();
  bool load();
  bool compile();
  bool print();
  ~RestSQLPreparer();
};

#endif
