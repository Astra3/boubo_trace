#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <linux/sched.h>
#include <sched.h>
#include <signal.h>

const char* MAIN_TEXT = "main thread\n";

int main() {
    write(STDOUT_FILENO, MAIN_TEXT, strlen(MAIN_TEXT));
    long child_tidptr;
    long res = syscall(SYS_clone, CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, NULL, NULL, &child_tidptr, 0);
    if (child_tidptr == 0) {
    // if (fork() == 0) {
        const char* msg = "hello from clone!\n";
        write(STDOUT_FILENO, msg, strlen(msg));
        return 0;
    }
    write(STDOUT_FILENO, MAIN_TEXT, strlen(MAIN_TEXT));
}
