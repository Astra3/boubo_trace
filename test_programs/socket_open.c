#include <sys/socket.h>

int main() {
    int sock = socket(AF_INET, SOCK_DGRAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 1);
}
