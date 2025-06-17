# Compiler and flags
CC = gcc
CXX = g++
CFLAGS = -Wall -Wextra -O3
LDFLAGS = 
THREADS ?= 4
TLOAD   ?= 1024
DEFINES = -DTHREAD_MIN_LOAD=$(TLOAD) -DTHREAD_AMOUNT=$(THREADS)

# --- Project Structure ---
# Directories for source files and compiled object files
SRCDIR = src
ODIR = lib

# Name of the final executable
EXECUTAVEL = ordena

# --- File Discovery ---
# Automatically find all .c files in the source directory
C_SRC_FILES = $(wildcard $(SRCDIR)/*.c)
CPP_SRC_FILES = $(wildcard $(SRCDIR)/*.cpp)

# Generate object file names by replacing 'src/' with 'lib/' and '.c' with '.o'
# Example: src/main.c becomes lib/main.o
C_OBJ_FILES = $(patsubst $(SRCDIR)/%.c, $(ODIR)/%.o, $(C_SRC_FILES))
CPP_OBJ_FILES = $(patsubst $(SRCDIR)/%.cpp, $(ODIR)/%.o, $(CPP_SRC_FILES))

# --- Build Rules ---

# The 'all' target is the default one, executed when you just run 'make'
# It depends on the final executable.
all: $(EXECUTAVEL)_1313 $(EXECUTAVEL) $(C_OBJ_FILES) $(CPP_OBJ_FILES)

# Rule to link the executable.
# This rule runs only after all its dependencies (the .o files) are built.
$(EXECUTAVEL): $(SRCDIR)/23201209.c
	@echo "==> Linking $@ from dependencies..."
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) $(DEFINES)
	@echo "==> Done. C Executable created at ./$@"

$(EXECUTAVEL)_1313: $(SRCDIR)/1313.cpp
	@echo "==> Linking $@ from dependencies..."
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)
	@echo "==> Done. C++ Executable created at ./$@"

# Pattern rule to compile source (.c) files into object (.o) files.
# This tells make how to build a file in 'lib/' from a file in 'src/'.
$(ODIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(ODIR) # Create the lib/ directory if it doesn't exist
	@echo "==> Compiling $< into $@..."
	$(CC) $(CFLAGS) -c $< -DSTRIP_MAIN -o $@ $(DEFINES)

$(ODIR)/%.o: $(SRCDIR)/%.cpp
	@mkdir -p $(ODIR) # Create the lib/ directory if it doesn't exist
	@echo "==> Compiling $< into $@..."
	$(CXX) $(CFLAGS) -c $< -DSTRIP_MAIN -o $@

# --- Utility Rules ---

# Rule to run the executable. Depends on 'all' to ensure the program is built first.
run: all
	./$(EXECUTAVEL) $(TAMANHO)

# Rule to clean up all generated files.
clean:
	@echo "==> Cleaning up build files..."
	rm -f $(EXECUTAVEL)
	rm -rf $(ODIR)
	@echo "==> Cleanup complete."

# Declare targets that are not actual files.
.PHONY: all run clean
