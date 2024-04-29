#!/usr/bin/env bash

runtest()
{
    local title ec
    title="$1"
    shift;
    echo -e "\n===== $title =====";
    "$@" 2>&1
    ec="$?"
    echo -e "=> Exit code: $ec"
}

# Test errors

runtest "Illegal character at beginning" ./ParseCompileTest $'\033select a from table;'
runtest "Illegal character at end" ./ParseCompileTest $'select a from table;\177'
runtest "Illegal character in identifier" ./ParseCompileTest $'select `a\005` from table;'

runtest "Illegal token" ./ParseCompileTest 'select #a from table;'

runtest "EOI inside quoted identifier" ./ParseCompileTest 'select `a'
runtest "EOI inside escaped identifier" ./ParseCompileTest 'select `bc``de'

runtest "Empty input" ./ParseCompileTest ''

runtest "Unexpected end of input" ./ParseCompileTest 'select a from table'

runtest "Unexpected at this point" ./ParseCompileTest $'select a `bcde` from table;'
runtest "Unexpected before newline" ./ParseCompileTest $'select a `bcde`\n from table;'
runtest "Unexpected after newline" ./ParseCompileTest $'select a \n`bcde` from table;'
runtest "Unexpected with ending newline" ./ParseCompileTest $'select a `bcde` from table;\n'
runtest "Unexpected with newline at start" ./ParseCompileTest $'\nselect a `bcde` from table;'
runtest "Unexpected containing newline" ./ParseCompileTest $'select a `bc\nde` from table;'
runtest "Unexpected containing two newlines" ./ParseCompileTest $'select a `b\ncd\ne` from table;'

runtest "Unexpected escaped identifier" ./ParseCompileTest $'select a `bc``de` from table;'

runtest "Two escaped identifiers, 1st unexpected" ./ParseCompileTest $'select a `bc``de` from `fg``h``i`;'
runtest "Two escaped identifiers, 2nd unexpected" ./ParseCompileTest $'select a, `bc``de` from table `fg``h``i`;'

# Test successes

runtest "APICompileTest" ./APICompileTest

runtest "Simple" ./ParseCompileTest 'select a from table;'
runtest "Arithmetics" ./ParseCompileTest 'select a, count(b), min((b+c)/(d-e)), max(d*e/f-b/c/f), count(b/c/f+d*e/f*(b+c)) from table;'
runtest "Quoted ID" ./ParseCompileTest $'select a, `b`, `c``c`, count(`d`), min((`e``e`+`f`)/(g-`h`)) from table;'

# Regression tests

runtest "has_item regression" ./ParseCompileTest '
select count(a+a+a+a+a+a+a+a+a+a+a+a+a+a+a+a+a)
      ,max(d*e/f-b/c/f)
      ,min((ee+f)/(g-h))
from table;'
