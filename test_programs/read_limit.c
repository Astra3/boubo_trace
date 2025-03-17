#include <fcntl.h>
#include <string.h>
#include <unistd.h>

int main() {
    int fd = open("/tmp/test_file", O_CREAT | O_WRONLY, S_IRWXU);
    char buf[256];
    memset(buf, 5, 256);
    write(fd, buf, 256);
    close(fd);
    unlink("/tmp/test_file");
}
