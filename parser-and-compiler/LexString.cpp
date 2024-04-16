#include "LexString.hpp"

std::ostream&
operator<< (std::ostream& os, const LexString& ls)
{
  os.write(ls.str, ls.len);
  return os;
};

bool
LexString::operator== (const LexString& other) const
{
  if (len != other.len) return false;
  if (len == 0) return true;
  return memcmp(str, other.str, len) == 0;
}
