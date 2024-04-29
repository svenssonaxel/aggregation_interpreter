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

# It's hard to make git work with files containing null bytes, so let's convert
# them to uppercase N in such test cases.
explainNUL()
{
    local ec tf
    tf="$(mktemp)"
    "$@" >"$tf" 2>&1
    ec=$?
    tr '\0' N < "$tf"
    rm "$tf"
    return $ec
}

# Test errors

runtest "Null byte at beginning" explainNUL ./ParseCompileTest 'select a from table;' 0
runtest "Null byte in identifier" explainNUL ./ParseCompileTest 'select a  from table;' 8
runtest "Null byte at end" explainNUL ./ParseCompileTest 'select a from table;' 19
runtest "Illegal UTF-8 byte" ./ParseCompileTest $'select a\xfa from table;'
runtest "Illegal 0xc0 UTF-8 byte" ./ParseCompileTest $'select a\xc0 from table;'
runtest "Illegal 0xc1 UTF-8 byte" ./ParseCompileTest $'select a\xc1 from table;'
# a = U+0061 = 01100001 ≈ 11000001 10100001 = c1 a1
runtest "UTF-8 overlong 2-byte sequence" ./ParseCompileTest $'select a\xc1\xa1 from table;'
# ö = U+00f6 = 11000011 10110110 ≈ 11100000 10000011 10110110 = e0 83 b6
runtest "UTF-8 overlong 3-byte sequence" ./ParseCompileTest $'select a\xe0\x83\xb6 from table;'
# U+123456 = 11110100 10100011 10010001 10010110 = f4 a3 91 96
runtest "Too high code point (U+123456)" ./ParseCompileTest $'select `a\xf4\xa3\x91\x96` from table;'
# U+dead = 11101101 10111010 10101101 = ed ba ad
runtest "Surrogate (U+dead)" ./ParseCompileTest $'select `a\xed\xba\xad` from table;'
# U+ffff < U+204d7 = 𠓗 = 11110000 10100000 10010011 10010111 = f0 a0 93 97
runtest "Non-BMP UTF-8 in identifier" ./ParseCompileTest $'select `a\xf0\xa0\x93\x97` from table;'
runtest "Illegal token" ./ParseCompileTest 'select #a from table;'
runtest "EOI inside quoted identifier" ./ParseCompileTest 'select `a'
runtest "EOI inside escaped identifier" ./ParseCompileTest 'select `bc``de'
# å = U+00e5 = 11000011 10100101 = c3 a5
runtest "UTF-8 2-byte sequence with illegal 2nd byte" ./ParseCompileTest $'select `a\xc3` from table;'
runtest "UTF-8 2-byte sequence at EOI with 2nd byte missing" ./ParseCompileTest $'select `a` from `table\xc3'
# ᚱ = U+16b1 = 11100001 10011010 10110001 = e1 9a b1
runtest "UTF-8 3-byte sequence with illegal 2nd byte" ./ParseCompileTest $'select `a\xe1` from table;'
runtest "UTF-8 3-byte sequence with illegal 3rd byte" ./ParseCompileTest $'select `a\xe1\x9a` from table;'
runtest "UTF-8 3-byte sequence at EOI with 2nd byte missing" ./ParseCompileTest $'select `a` from `table\xe1'
runtest "UTF-8 3-byte sequence at EOI with 3rd byte missing" ./ParseCompileTest $'select `a` from `table\xe1\x9a'
# 𠓗 = U+204d7 = 11110000 10100000 10010011 10010111 = f0 a0 93 97
runtest "UTF-8 4-byte sequence with illegal 2nd byte" ./ParseCompileTest $'select `a\xf0` from table;'
runtest "UTF-8 4-byte sequence with illegal 3rd byte" ./ParseCompileTest $'select `a\xf0\xa0` from table;'
runtest "UTF-8 4-byte sequence with illegal 4th byte" ./ParseCompileTest $'select `a\xf0\xa0\x93` from table;'
runtest "UTF-8 4-byte sequence at EOI with 2nd byte missing" ./ParseCompileTest $'select `a` from `table\xf0'
runtest "UTF-8 4-byte sequence at EOI with 3rd byte missing" ./ParseCompileTest $'select `a` from `table\xf0\xa0'
runtest "UTF-8 4-byte sequence at EOI with 4th byte missing" ./ParseCompileTest $'select `a` from `table\xf0\xa0\x93'
runtest "Rogue UTF-8 continuation byte" ./ParseCompileTest $'select a\x89 from table;'
runtest "Empty input" ./ParseCompileTest ''
runtest "Invalid token at beginning" ./ParseCompileTest $'\033select a from table;'
runtest "Control character in unquoted identifier" ./ParseCompileTest $'select a\005 from table;'
runtest "Invalid token at end" ./ParseCompileTest $'select a from table;\177'
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
runtest "Error marker alignment after 2-byte UTF-8 characters" ./ParseCompileTest $'select a\n      ,räksmörgås räksmörgås\nfrom table;'
runtest "Error marker alignment after 3-byte UTF-8 character" ./ParseCompileTest $'select a\n      ,ᚱab ᚱab\nfrom table;'

# Test successes

runtest "APICompileTest" ./APICompileTest
runtest "Simple" ./ParseCompileTest 'select a from table;'
runtest "Arithmetics" ./ParseCompileTest 'select a, count(b), min((b+c)/(d-e)), max(d*e/f-b/c/f), count(b/c/f+d*e/f*(b+c)) from table;'
runtest "Quoted ID" ./ParseCompileTest $'select a, `b`, `c``c`, count(`d`), min((`e``e`+`f`)/(g-`h`)) from table;'
# å = U+00e5 = c3 a5
runtest "UTF-8 2-byte character in unquoted identifier" ./ParseCompileTest $'select a\xc3\xa5 from table;'
runtest "UTF-8 2-byte character in quoted identifier" ./ParseCompileTest $'select `a\xc3\xa5` from table;'
# ᚱ = U+16b1 = 11100001 10011010 10110001 = e1 9a b1
runtest "UTF-8 3-byte character in unquoted identifier" ./ParseCompileTest $'select a\xe1\x9a\xb1 from table;'
runtest "UTF-8 3-byte character in quoted identifier" ./ParseCompileTest $'select `a\xe1\x9a\xb1` from table;'
runtest "Control character in quoted identifier" ./ParseCompileTest $'select `a\005` from table;'
runtest "has_item regression" ./ParseCompileTest '
select count(a+a+a+a+a+a+a+a+a+a+a+a+a+a+a+a+a)
      ,max(d*e/f-b/c/f)
      ,min((ee+f)/(g-h))
from table;'
