#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>

const char* FILES[] = {"file1.txt", "file2.txt"};
const char* MAIN_TEXT = "main thread\n";

void* thread(void* arg) {
    char buf[256];
    sprintf(buf, "hello from thread %zu\n", (size_t)arg);
    write(STDOUT_FILENO, buf, strlen(buf));
    return (void*)0;
}

int main() {
    write(STDOUT_FILENO, MAIN_TEXT, strlen(MAIN_TEXT));
    pthread_t threads[2];
    pthread_create(&threads[0], NULL, thread, (void*)0);
    pthread_create(&threads[1], NULL, thread, (void*)1);
    pthread_join(threads[0], NULL);
    pthread_join(threads[1], NULL);
    write(STDOUT_FILENO, MAIN_TEXT, strlen(MAIN_TEXT));
}

