#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

#define PORT 8080

int main() {
    int sock = socket(AF_INET, SOCK_STREAM, 0);

    struct sockaddr_in sock_addr;
    bzero(&sock_addr, sizeof(sock_addr));
    struct in_addr addr = { INADDR_ANY };
    sock_addr.sin_family = AF_INET;
    sock_addr.sin_port = htons(PORT);
    sock_addr.sin_addr = addr;

    if (bind(sock, (const struct sockaddr*) &sock_addr, sizeof(sock_addr)) == -1) {
        perror("server bind error");
        return EXIT_FAILURE;
    }
    listen(sock, 1);

    if (syscall(SYS_fork) == 0) {
        close(sock);
        sock_addr.sin_addr.s_addr = inet_addr("127.0.0.1");

        sock = socket(AF_INET, SOCK_STREAM, 0);
        if (connect(sock, (const struct sockaddr*) &sock_addr, sizeof(sock_addr)))
            perror("client connect error");
        close(sock);
        return EXIT_SUCCESS;
    }

    struct sockaddr_in rsa;
    socklen_t length = sizeof(rsa);
    int new_sock = accept(sock, (struct sockaddr*) &rsa, &length);

    close(new_sock);
    close(sock);
}
