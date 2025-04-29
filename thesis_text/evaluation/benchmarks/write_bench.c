#include <unistd.h>
#include <fcntl.h>
#include <sys/random.h>

int main() {
    int fd = open("/dev/null", O_WRONLY);
    char buf[256];
    for (size_t i = 0; i < 1000000; i++) {
        getrandom(buf, sizeof(buf), GRND_RANDOM);
        write(fd, buf, sizeof(buf));
    }
    close(fd);
}
