#include <errno.h>
#include <stdio.h>
#include <unistd.h>

int main() {
    int ret = execl("./open.exec", "", NULL);
    printf("errno value: %d\n", errno);
    perror("");
}
