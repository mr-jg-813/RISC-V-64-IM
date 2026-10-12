int brisc_user_main(void);

int main(void) {
    int status = brisc_user_main();
    __asm__ volatile ("li a0, 0\n\tebreak" ::: "a0", "memory");
    return status;
}
