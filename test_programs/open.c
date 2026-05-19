#include <fcntl.h>
#include <unistd.h>

int main() {
    const char msg[] = "Hello world!\n";
    int descriptor = open("/tmp/test.txt", O_RDWR | O_CREAT | O_TRUNC, S_IRWXU);
    write(descriptor, msg, sizeof(msg) - 1);
    close(descriptor);
    unlink("/tmp/test.txt");

    descriptor = open("/tm/test.txt", O_RDWR | O_CREAT | O_TRUNC, S_IRWXU);
}
