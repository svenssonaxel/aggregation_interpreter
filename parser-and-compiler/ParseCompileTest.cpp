#include <stdio.h>
#include <stdlib.h>
#include <stdexcept>
#include <assert.h>
#include "RestSQLPreparer.hpp"
#include "ArenaAllocator.hpp"
using std::cout;
using std::endl;

int
main(int argc, char** argv)
{

  ArenaAllocator aalloc;

  assert(argc==2 || argc==3);

  // bison requires two NUL bytes at end
  char* cmdline_arg = argv[1];
  int cmdline_arg_len = strlen(cmdline_arg);
  LexString string_to_parse =
  {
    static_cast<char*>(aalloc.alloc((cmdline_arg_len+2) * sizeof(char))),
    (cmdline_arg_len+2) * sizeof(char)
  };
  memcpy(string_to_parse.str, cmdline_arg, cmdline_arg_len);
  string_to_parse.str[cmdline_arg_len] = '\0';
  string_to_parse.str[cmdline_arg_len+1] = '\0';
  if(argc==3)
  {
    // Test a string containing a null byte at a certain position
    string_to_parse.str[atoi(argv[2])] = '\0';
  }

  try
  {
    RestSQLPreparer prepare(string_to_parse, &aalloc);
    if(!prepare.parse())
    {
      printf("Failed to parse.\n");
      return 1;
    }
    if(!prepare.load())
    {
      printf("Failed to load.\n");
      return 1;
    }
    if(!prepare.compile())
    {
      printf("Failed to compile.\n");
      return 1;
    }
    if(!prepare.print())
    {
      printf("Failed to print.\n");
      return 1;
    }
  }
  catch(std::runtime_error& e)
  {
    printf("Caught exception: %s\n", e.what());
    return 1;
  }

  if(argc == 1)
  {
    printf("Usage: %s SQL_QUERY_1 [ SQL_QUERY_2 ... ]\n", argv[0]);
  }

  return 0;
}
