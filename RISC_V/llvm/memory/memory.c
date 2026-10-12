#include <stdio.h>

int main(void)
{
    int memory = 12345;  // Stored in data memory
    int *pointer = &memory;

    int loaded_value = *pointer;  // Load from memory through the pointer

    printf("Value loaded from memory: %d\n", loaded_value);
    return 0;
}
