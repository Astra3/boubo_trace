#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

int main() {
    const char msg[] = "Hello world!\n";
    //long val = write(STDOUT_FILENO, msg, sizeof(msg) - 1);
    //write(STDOUT_FILENO, msg, sizeof(msg) - 1);
    int descriptor = open("test.txt", O_RDWR | O_CREAT , S_IRWXU);
    //printf("Descriptor: %d\n", descriptor);
    // write(descriptor, msg, sizeof(msg) - 1);
    char buf[20] = {0};
    int ret = read(descriptor, buf, sizeof(buf));
    // printf("returned: %d\n", ret);
    // printf("read: %s\n", buf);
    close(descriptor);
    //printf("Written: %#08lx\n", val);
}
