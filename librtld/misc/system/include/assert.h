#pragma once

#include <stdnoreturn.h>
#define NORETURN __attribute__ ((noreturn))
NORETURN void __assert (const char *msg, const char *file, int line);

#define assert(EX) (void)((EX) || (__assert (#EX, __FILE__, __LINE__),0))
