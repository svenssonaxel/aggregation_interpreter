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

#include "ArenaAllocator.hpp"

ArenaAllocator::ArenaAllocator()
{
  m_point = &m_initial_stack_allocated_page[0];
  m_stop = ((byte*)this) + sizeof(*this);
}

ArenaAllocator::~ArenaAllocator()
{
  while (m_current_page)
  {
    Page* next = (Page*)m_current_page->next;
    free(m_current_page);
    m_current_page = next;
  }
# ifdef ARENA_ALLOCATOR_DEBUG
  printf("In ~ArenaAllocator\n"
         "  Total allocated by us: %u\n"
         "  Total allocated by user: %u\n"
         "  Efficiency: %u%%\n",
         m_allocated_by_us,
         m_allocated_by_user,
         100 * m_allocated_by_user / m_allocated_by_us);
# endif
}

void*
ArenaAllocator::alloc(size_t size)
{
  byte* new_point = m_point + size;
  if (new_point > m_stop)
  {
    if (0x40000000 <= 2 * size + OVERHEAD)
    {
      throw std::runtime_error(
        "ArenaAllocator: Requested allocation size too large"
      );
    }
    while (m_page_data_size < 2 * size + OVERHEAD)
    {
      m_page_data_size *= 2;
    }
    Page* new_page = (Page*)malloc(m_page_data_size);
    if (!new_page)
    {
      throw std::runtime_error("ArenaAllocator: Out of memory");
    }
#   ifdef ARENA_ALLOCATOR_DEBUG
    m_allocated_by_us += m_page_data_size;
#   endif
    new_page->next = m_current_page;
    m_current_page = new_page;
    m_point = new_page->data;
    m_stop = ((byte*)new_page) + m_page_data_size;
    new_point = m_point + size;
    assert(new_point < m_stop);
  }
  void* ret = m_point;
  m_point = new_point;
# ifdef ARENA_ALLOCATOR_DEBUG
  m_allocated_by_user += size;
# endif
  return ret;
}
