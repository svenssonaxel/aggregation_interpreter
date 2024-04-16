#ifndef ArenaAllocator_hpp_included
#define ArenaAllocator_hpp_included 1

#include <assert.h>
#include <stdexcept>

//#define ARENA_ALLOCATOR_DEBUG 1

class ArenaAllocator
{
private:
  enum class byte : uint8_t {};
  /*
   * todo: These two parameters could be dynamic. With some statistics, we
   * should be able to tune these as a function of SQL statement length, which
   * we'll probably know before we create the arena allocator.
   */
  static const size_t DEFAULT_PAGE_SIZE = 256;
  static const size_t INITIAL_PAGE_SIZE = 80;
  size_t m_page_data_size = DEFAULT_PAGE_SIZE;
  struct Page
  {
    struct Page* next = NULL;
    byte data[1]; // Actually an arbitrary amount
  };
  static const size_t OVERHEAD = offsetof(struct Page, data);
  static_assert(OVERHEAD < DEFAULT_PAGE_SIZE, "default page size too small");
  struct Page* m_current_page = NULL;
  byte* m_point = NULL;
  byte* m_stop = NULL;
  #ifdef ARENA_ALLOCATOR_DEBUG
  uint m_allocated_by_us = sizeof(ArenaAllocator);
  uint m_allocated_by_user = 0;
  #endif
  byte m_initial_stack_allocated_page[INITIAL_PAGE_SIZE]; // MUST be last!
public:
  ArenaAllocator();
  ~ArenaAllocator();
  void *alloc(size_t size);
};

#endif
