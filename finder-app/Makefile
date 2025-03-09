# Compiler and flags
CC := $(CROSS_COMPILE)gcc
CFLAGS := -Wall -Werror -g

# Target application
TARGET := writer

# Source files
SRCS := writer.c
OBJS := $(SRCS:.c=.o)

# Default target (builds the application)
all: $(TARGET)

# Build the writer application
$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^

# Compile source files into object files
%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Clean target
clean:
	rm -f $(TARGET) $(OBJS)
