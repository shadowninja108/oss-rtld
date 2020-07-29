#pragma once

#define noreturn __attribute__((noreturn))
noreturn void __assert (const char *msg, const char *file, int line);

#define assert(EX) (void)((EX) || (__assert (#EX, __FILE__, __LINE__),0))
