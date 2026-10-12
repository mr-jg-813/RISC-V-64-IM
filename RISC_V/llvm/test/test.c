#include <stdint.h>
#include <stdio.h>

#define ITEMS 32u
#define ROUNDS 64u

static volatile uint8_t byte_mem[ITEMS];
static volatile uint16_t half_mem[ITEMS];
static volatile uint32_t word_mem[ITEMS];
static volatile uint64_t double_mem[ITEMS];
static volatile int8_t signed_byte_mem[ITEMS];
static volatile int16_t signed_half_mem[ITEMS];
static volatile int32_t signed_word_mem[ITEMS];

int main(void)
{
    uint32_t i;
    uint32_t round;
    uint32_t checksum = 0;

    printf("BRISC-V C stress test starting\n");

    /* Exercise byte, halfword, word, and doubleword stores. */
    for (i = 0; i < ITEMS; ++i) {
        byte_mem[i] = (uint8_t)(0x80u + i);
        half_mem[i] = (uint16_t)(0x8000u + i);
        word_mem[i] = 0x80000000u + i;
        double_mem[i] = 0x8000000000000000ULL + i;
        signed_byte_mem[i] = (int8_t)(-120 + (int)i);
        signed_half_mem[i] = (int16_t)(-32000 + (int)i);
        signed_word_mem[i] = -2000000000 + (int32_t)i;
    }

    /* Read back each width, including unsigned loads with the top bit set. */
    for (i = 0; i < ITEMS; ++i) {
        if (byte_mem[i] != (uint8_t)(0x80u + i)) {
            printf("FAIL: byte load/store at index %u\n", (unsigned)i);
            return 1;
        }
        if (half_mem[i] != (uint16_t)(0x8000u + i)) {
            printf("FAIL: halfword load/store at index %u\n", (unsigned)i);
            return 1;
        }
        if (word_mem[i] != 0x80000000u + i) {
            printf("FAIL: word load/store at index %u\n", (unsigned)i);
            return 1;
        }
        if (double_mem[i] != 0x8000000000000000ULL + i) {
            printf("FAIL: doubleword load/store at index %u\n", (unsigned)i);
            return 1;
        }
        if (signed_byte_mem[i] != (int8_t)(-120 + (int)i)) {
            printf("FAIL: signed byte load at index %u\n", (unsigned)i);
            return 1;
        }
        if (signed_half_mem[i] != (int16_t)(-32000 + (int)i)) {
            printf("FAIL: signed halfword load at index %u\n", (unsigned)i);
            return 1;
        }
        if (signed_word_mem[i] != -2000000000 + (int32_t)i) {
            printf("FAIL: signed word load at index %u\n", (unsigned)i);
            return 1;
        }
    }
    printf("PASS: signed and unsigned byte/halfword/word loads; stores at all widths\n");

    /* Repeated dependent arithmetic and read/write traffic. */
    for (round = 0; round < ROUNDS; ++round) {
        for (i = 0; i < ITEMS; ++i) {
            uint32_t next_word = word_mem[i] + round + i + 1u;
            uint64_t next_double = double_mem[i] ^
                ((uint64_t)(round + 1u) << (i & 31u));

            word_mem[i] = next_word;
            double_mem[i] = next_double;

            if (word_mem[i] != next_word || double_mem[i] != next_double) {
                printf("FAIL: repeated memory check, round %u index %u\n",
                       (unsigned)round, (unsigned)i);
                return 1;
            }

            checksum ^= next_word ^ (uint32_t)next_double;
        }
    }

    printf("PASS: %u rounds x %u words; checksum=%u\n",
           (unsigned)ROUNDS, (unsigned)ITEMS, (unsigned)checksum);
    printf("BRISC-V C stress test complete\n");
    return 0;
}
