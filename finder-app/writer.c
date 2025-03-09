#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>

int main(int argc, char *argv[]) {
    // Open syslog for logging
    openlog("writer", LOG_PID, LOG_USER);

    // Check for required arguments
    if (argc != 3) {
        syslog(LOG_ERR, "Error: Incorrect number of arguments.");
        fprintf(stderr, "Usage: %s <file_path> <text_string>\n", argv[0]);
        closelog();
        return 1;
    }

    const char *writefile = argv[1];
    const char *writestr = argv[2];

    // Open the file for writing (overwrite if exists)
    FILE *file = fopen(writefile, "w");
    if (file == NULL) {
        syslog(LOG_ERR, "Error: Unable to open file %s for writing", writefile);
        perror("fopen");
        closelog();
        return 1;
    }

    // Write the string to the file
    if (fprintf(file, "%s", writestr) < 0) {
        syslog(LOG_ERR, "Error: Failed to write to file %s", writefile);
        fclose(file);
        closelog();
        return 1;
    }

    // Close the file
    fclose(file);

    // Log the successful write operation
    syslog(LOG_DEBUG, "Writing '%s' to '%s'", writestr, writefile);

    // Close syslog
    closelog();
    
    return 0;
}

