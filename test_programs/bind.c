#include <stdio.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

int main() {
    int sock = socket(AF_INET, SOCK_STREAM, 0);

    struct sockaddr_in sock_addr;
    struct in_addr addr = { INADDR_ANY };
    sock_addr.sin_family = AF_INET;
    sock_addr.sin_port = htons(8080);
    sock_addr.sin_addr = addr;

    if (bind(sock, (const struct sockaddr*) &sock_addr, sizeof(sock_addr)) == -1)
        perror("bind failed");
    listen(sock, 1);

    struct sockaddr_in rsa;
    socklen_t length = sizeof(rsa);
    int new_sock = accept(sock, (struct sockaddr*) &rsa, &length);

    close(new_sock);
    close(sock);
}
