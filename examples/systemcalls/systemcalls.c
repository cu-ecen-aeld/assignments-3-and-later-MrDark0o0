#include "systemcalls.h"
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdarg.h>
#include <stdio.h>

/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed successfully using system()
 */
bool do_system(const char *cmd)
{
    if (cmd == NULL) {
        return false;
    }

    int ret = system(cmd);

    if (ret == -1) {
        return false;
    }

    // Return true only if command exits with 0 status
    return WIFEXITED(ret) && WEXITSTATUS(ret) == 0;
}


/**
 * Executes a command using fork/execv/waitpid.
 */
bool do_exec(int count, ...)
{
    va_list args;
    va_start(args, count);

    // Prepare argument array for execv
    char *command[count + 1];
    for (int i = 0; i < count; i++) {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;

    va_end(args);

    pid_t pid = fork();
    if (pid < 0) {
        perror("fork failed");
        return false;
    }

    if (pid == 0) {
        // Child process
        execv(command[0], command);
        // If execv returns, it's an error
        perror("execv failed");
        exit(1);
    }

    // Parent process
    int status;
    if (waitpid(pid, &status, 0) == -1) {
        perror("waitpid failed");
        return false;
    }

    return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}


/**
 * Executes a command with output redirected to a file.
 */
bool do_exec_redirect(const char *outputfile, int count, ...)
{
    va_list args;
    va_start(args, count);

    char *command[count + 1];
    for (int i = 0; i < count; i++) {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
    va_end(args);

    pid_t pid = fork();
    if (pid < 0) {
        perror("fork failed");
        return false;
    }

    if (pid == 0) {
        // Child process
        int fd = open(outputfile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0) {
            perror("open failed");
            exit(1);
        }

        // Redirect stdout and stderr
        dup2(fd, STDOUT_FILENO);
        dup2(fd, STDERR_FILENO);
        close(fd);

        execv(command[0], command);
        // If execv fails
        perror("execv failed");
        exit(1);
    }

    // Parent process
    int status;
    if (waitpid(pid, &status, 0) == -1) {
        perror("waitpid failed");
        return false;
    }

    return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

