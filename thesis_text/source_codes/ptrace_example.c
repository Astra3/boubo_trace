#include <stdio.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <unistd.h>

int main() {
    pid_t pid = fork();
    if (pid == 0) {
        // proces potomka
        // dovolujeme rodiči použít ptrace na tento proces
        ptrace(PTRACE_TRACEME);
        execl("/usr/bin/ls", "ls", NULL);
    }

    int status;
    // čekáme, než se potomek zastaví
    waitpid(pid, &status, 0);
    if (!WIFSTOPPED(status)) { return 1; }
    // pokračujeme exekuci potomka
    ptrace(PTRACE_CONT, pid, NULL, NULL);
    // počkáme, než potomek skončí
    wait(NULL);
}
