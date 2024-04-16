#ifndef LexString_hpp_included
#define LexString_hpp_included 1

#include <cstddef>
#include <cstring>
#include <iostream>

class LexString
{
public:
  char *str;
  size_t len;
  LexString() = default;
  LexString(const LexString& other) = default;
  LexString& operator= (const LexString& other) = default;
  ~LexString() = default;
  friend std::ostream& operator<< (std::ostream& out, const LexString& ls);
  bool operator== (const LexString& other) const;
};

#endif
