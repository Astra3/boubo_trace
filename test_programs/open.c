#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

int main() {
    const char msg[] = "Hello warld!\n";
    //long val = write(STDOUT_FILENO, msg, sizeof(msg) - 1);
    //write(STDOUT_FILENO, msg, sizeof(msg) - 1);
    int descriptor = open("test.txt", O_RDWR | O_CREAT | O_TRUNC, S_IRWXU);
    //printf("Descriptor: %d\n", descriptor);
    write(descriptor, msg, sizeof(msg) - 1);
    close(descriptor);
    //printf("Written: %#08lx\n", val);
}
