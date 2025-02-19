#include <errno.h>
#include <stdio.h>
#include <unistd.h>

int main(int argv, char** argc, char* envp[]) {
    int ret = execve("./open.exec", NULL, envp);
    printf("errno value: %d\n", errno);
    perror("");
}
