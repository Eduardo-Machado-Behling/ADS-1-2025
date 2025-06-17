#!/bin/bash

# ==============================================================================
#
#                      Single-Run Benchmark Script
#
# Description:
#   This script automates a single benchmark run for a C/C++ project.
#   It cleans the build, compiles the project with specific preprocessor
#   definitions (passed to make), links the final executable, runs the
#   benchmark using Google Benchmark, and saves the output to a specified
#   or auto-generated CSV file.
#
# ==============================================================================

# --- Script Configuration & Safety ---

# Exit immediately if a command fails.
set -e
# Ensure that pipelines fail if any command fails, not just the last one.
set -o pipefail

# --- Default Parameters ---

DEFAULT_THREADS=8
DEFAULT_TLOAD=1024
DEFAULT_SAMPLE=32
DEFAULT_GAP=16
DEFAULT_BEGIN=8
DEFAULT_OUTPUT_FILE="" # If empty, a name is auto-generated.

# --- File Paths & Build Config ---

# List of object files needed for the final linking stage.
# These should be the output of the 'make' command.
OBJECT_FILES=(
    "./lib/mergesort.o"
    "./lib/23201209.o"
    "./lib/Cormen.o"
    "./lib/1313.o"
    "./lib/qsort.o"
)
BENCH_HARNESS_SRC="./benchmark/main.cpp"
FINAL_EXECUTABLE="./bench_sorts"
DATA_DIR="./data"

# Compiler and Linker flags
CXXFLAGS="-O2"
LDFLAGS="-lbenchmark -lpthread"

# --- Functions ---

#
# Prints usage information and exits.
#
function usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Configures, builds, and runs a single benchmark."
    echo
    echo "Options:"
    echo "  -t <num>    Number of THREADS to pass to make (default: ${DEFAULT_THREADS})"
    echo "  -l <num>    TLOAD value to pass to make (default: ${DEFAULT_TLOAD})"
    echo "  -s <num>    SAMPLE size for the benchmark (default: ${DEFAULT_SAMPLE})"
    echo "  -g <num>    GAP value for the benchmark (default: ${DEFAULT_GAP})"
    echo "  -b <num>    BEGIN value for the benchmark (default: ${DEFAULT_BEGIN})"
    echo "  -o <file>   Output CSV file path. If not set, a name is auto-generated."
    echo "  -h          Display this help message."
    echo
    exit 1
}

#
# Cleans up temporary files. Designed to be called on script exit.
#
function cleanup() {
    echo "--- Cleaning up temporary executable ---"
    rm -f "${FINAL_EXECUTABLE}"
}

# --- Argument Parsing ---

# Assign defaults
THREADS=$DEFAULT_THREADS
TLOAD=$DEFAULT_TLOAD
SAMPLE=$DEFAULT_SAMPLE
GAP=$DEFAULT_GAP
BEGIN=$DEFAULT_BEGIN
OUTPUT_FILE=$DEFAULT_OUTPUT_FILE

while getopts "t:l:s:g:b:o:h" opt; do
    case ${opt} in
        t) THREADS=$OPTARG ;;
        l) TLOAD=$OPTARG ;;
        s) SAMPLE=$OPTARG ;;
        g) GAP=$OPTARG ;;
        b) BEGIN=$OPTARG ;;
        o) OUTPUT_FILE=$OPTARG ;;
        h) usage ;;
        \?) echo "Invalid Option: -$OPTARG" >&2; usage ;;
    esac
done

# --- Main Logic ---

# Trap ensures 'cleanup' is called when the script exits (for any reason).
trap cleanup EXIT

# 1. Determine Final Output Filename
if [ -z "${OUTPUT_FILE}" ]; then
    # Auto-generate the filename if one wasn't provided.
    mkdir -p "${DATA_DIR}"
    OUTPUT_FILE="${DATA_DIR}/T${THREADS}_L${TLOAD}_S${SAMPLE}.csv"
fi
echo "--- Benchmark results will be saved to: ${OUTPUT_FILE} ---"

# 2. Compile the code using the Makefile
echo "--- Compiling with THREADS=${THREADS}, TLOAD=${TLOAD} ---"
make clean
make THREADS="${THREADS}" TLOAD="${TLOAD}"

# 3. Link the final executable
echo "--- Linking final benchmark executable ---"
g++ ${CXXFLAGS} "${BENCH_HARNESS_SRC}" "${OBJECT_FILES[@]}" ${LDFLAGS} \
    -o "${FINAL_EXECUTABLE}" \
    -DSAMPLE="${SAMPLE}" \
    -DGAP="${GAP}" \
    -DBEGIN="${BEGIN}"

# 4. Run the benchmark
echo "--- Running benchmark ---"
"./${FINAL_EXECUTABLE}" --benchmark_out="${OUTPUT_FILE}" --benchmark_out_format=csv

echo
echo "--- Benchmark complete. ---"
