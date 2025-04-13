#include <fcntl.h>
#include <unistd.h>

int main() {
    const char msg[] = "Hello warld!\n";
    int descriptor = open("test.txt", O_RDWR | O_CREAT | O_TRUNC, S_IRWXU);
    write(descriptor, msg, sizeof(msg) - 1);
    close(descriptor);
}
