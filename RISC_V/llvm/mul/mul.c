#include <stdint.h>
#include <stdio.h>

static int failures;

static void check(const char *name, uint64_t actual, uint64_t expected)
{
    if (actual == expected) {
        puts("PASS:");
        puts(name);
    } else {
        puts("FAIL:");
        puts(name);
        failures++;
    }
}

#define RUN_M(name, instruction, lhs, rhs, expected) do {                 \
    uint64_t actual;                                                      \
    __asm__ volatile (instruction " %0, %1, %2"                         \
        : "=r" (actual) : "r" (lhs), "r" (rhs));                        \
    check(name, actual, (uint64_t)(expected));                             \
} while (0)

int main(void)
{
    volatile int64_t signed_a = -1234567890123LL;
    volatile int64_t signed_b = 987654321LL;
    volatile uint64_t unsigned_a = 0xfedcba9876543210ULL;
    volatile uint64_t unsigned_b = 0x123456789abcdef1ULL;

    volatile int64_t div_signed_a = -100;
    volatile int64_t div_signed_b = 7;
    volatile uint64_t div_unsigned_a = 100;
    volatile uint64_t div_unsigned_b = 7;

    volatile int64_t word_signed_a = -1234;
    volatile int64_t word_signed_b = 567;
    volatile uint64_t word_unsigned_a = 100;
    volatile uint64_t word_unsigned_b = 7;

    /* RV64M multiply instructions. */
    RUN_M("MUL", "mul", signed_a, signed_b,
          0xe672bc30117537a5ULL);
    RUN_M("MULH", "mulh", signed_a, signed_b,
          0xffffffffffffffbdULL);
    RUN_M("MULHSU", "mulhsu", signed_a, unsigned_a,
          0xfffffee1d5117985ULL);
    RUN_M("MULHU", "mulhu", unsigned_a, unsigned_b,
          0x121fa00ad77d7423ULL);
    RUN_M("MULW", "mulw", word_signed_a, word_signed_b,
          0xfffffffffff552e2ULL);

    /* RV64M 64-bit divide and remainder instructions. */
    RUN_M("DIV", "div", div_signed_a, div_signed_b,
          0xfffffffffffffff2ULL); /* -100 / 7 = -14 */
    RUN_M("DIVU", "divu", div_unsigned_a, div_unsigned_b, 14);
    RUN_M("REM", "rem", div_signed_a, div_signed_b,
          0xfffffffffffffffeULL); /* -100 % 7 = -2 */
    RUN_M("REMU", "remu", div_unsigned_a, div_unsigned_b, 2);

    /* RV64M 32-bit word divide and remainder instructions. */
    RUN_M("DIVW", "divw", div_signed_a, div_signed_b,
          0xfffffffffffffff2ULL);
    RUN_M("DIVUW", "divuw", word_unsigned_a, word_unsigned_b, 14);
    RUN_M("REMW", "remw", div_signed_a, div_signed_b,
          0xfffffffffffffffeULL);
    RUN_M("REMUW", "remuw", word_unsigned_a, word_unsigned_b, 2);

    if (failures == 0) {
        puts("All 13 RV64M arithmetic instructions passed.");
        return 0;
    }

    puts("RV64M arithmetic test failed.");
    return 1;
}
