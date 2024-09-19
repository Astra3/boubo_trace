#include <stdio.h>
#include <unistd.h>

int main() {
    const char msg[] = "Hello world!\n";
    long val = write(STDOUT_FILENO, msg, sizeof(msg) - 1);
    printf("Written: %#08lx\n", val);
}
