#include "ArenaAllocator.hpp"

ArenaAllocator::ArenaAllocator()
{
  m_point = &m_initial_stack_allocated_page[0];
  m_stop = ((byte*)this) + sizeof(*this);
}

ArenaAllocator::~ArenaAllocator()
{
  while(m_current_page)
  {
    Page* next = (Page*)m_current_page->next;
    free(m_current_page);
    m_current_page = next;
  }
  #ifdef ARENA_ALLOCATOR_DEBUG
  printf("In ~ArenaAllocator\n"
         "  Total allocated by us: %u\n"
         "  Total allocated by user: %u\n"
         "  Efficiency: %u%%\n",
         m_allocated_by_us,
         m_allocated_by_user,
         100 * m_allocated_by_user / m_allocated_by_us);
  #endif
}

void*
ArenaAllocator::alloc(size_t size)
{
  byte* new_point = m_point + size;
  if(new_point > m_stop)
  {
    if(0x40000000 <= 2 * size + OVERHEAD)
    {
      throw std::runtime_error(
        "ArenaAllocator: Requested allocation size too large"
      );
    }
    while(m_page_data_size < 2 * size + OVERHEAD)
    {
      m_page_data_size *= 2;
    }
    Page* new_page = (Page*)malloc(m_page_data_size);
    if(!new_page)
    {
      throw std::runtime_error("ArenaAllocator: Out of memory");
    }
    #ifdef ARENA_ALLOCATOR_DEBUG
    m_allocated_by_us += m_page_data_size;
    #endif
    new_page->next = m_current_page;
    m_current_page = new_page;
    m_point = new_page->data;
    m_stop = ((byte*)new_page) + m_page_data_size;
    new_point = m_point + size;
    assert(new_point < m_stop);
  }
  void* ret = m_point;
  m_point = new_point;
  #ifdef ARENA_ALLOCATOR_DEBUG
  m_allocated_by_user += size;
  #endif
  return ret;
}
