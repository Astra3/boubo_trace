#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

int main() {
    int descriptor = open("/tmp/test.txt", O_RDWR | O_CREAT | O_TRUNC, S_IRWXU);
    for (size_t i = 0; i < 12000000000; i++) {
        __asm__("nop");
    }
    const char msg[] = "Hello world!\n";
    write(descriptor, msg, sizeof(msg) - 1);
    close(descriptor);
    unlink("/tmp/test.txt");

    descriptor = open("/tm/test.txt", O_RDWR | O_CREAT | O_TRUNC, S_IRWXU);
}
