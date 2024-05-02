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

/*
 * Return a concatenation of two LexStrings. The lifetime of the returned
 * LexString will end when the lifetime of either argument or the allocator
  * ends.
 */
LexString
LexString::concat(const LexString other, ArenaAllocator allocator)
{
  if(this->str == NULL &&
     this->len == 0)
  {
    return other;
  }
  if(&this->str[this->len] == other.str) {
    // The lifetime of the returned LexString will end when the lifetime of
    // either argument ends.
    return LexString{this->str, this->len + other.len};
  }
  size_t concatenated_len = this->len + other.len;
  // It's possible that concatenated_str == this->str. The lifetime of the
  // returned LexString will end when the lifetime of either argument or the
  // allocator ends.
  char* concatenated_str = (char*)allocator.realloc(this->str,
                                                    concatenated_len,
                                                    this->len);
  memcpy(concatenated_str, this->str, this->len);
  memcpy(&concatenated_str[this->len], other.str, other.len);
  return LexString{concatenated_str, concatenated_len};
}
