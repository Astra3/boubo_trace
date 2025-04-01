#include <string.h>
#include <unistd.h>

const char* TEXT = "Hello World!\n";
int main() {
    write(STDOUT_FILENO, TEXT, strlen(TEXT));
}
