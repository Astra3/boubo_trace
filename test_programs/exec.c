#include <errno.h>
#include <stdio.h>
#include <unistd.h>

int main(int argv, char** argc, char* envp[]) {
    execve("./opan.exec", NULL, envp);
    execve("./open.exec", NULL, envp);
}
