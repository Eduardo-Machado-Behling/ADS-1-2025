#!/bin/bash

# ==============================================================================
#
#                    Matrix Benchmark & Compilation Script
#
# Description:
#   This script automates the process of performance benchmarking for a C/C++
#   project across a matrix of different configurations. It has two phases:
#
#   1. Compilation Phase: It compiles a source file multiple times, each time
#      with a different set of preprocessor definitions (e.g., for thread
#      count and workload size), creating a unique object file for each variant.
#
#   2. Benchmarking Phase: It iterates through each compiled object file, links
#      it against a Google Benchmark harness, runs the benchmark, and processes
#      the output, appending the results and configuration parameters to a
#      single, clean CSV file.
#
# ==============================================================================

# --- Script Configuration & Safety ---

# Exit immediately if a command fails.
set -e
# Exit if any command in a pipeline fails, not just the last one. Crucial for the `sed | awk` pipe.
set -o pipefail

# --- Default Parameters ---

# These can be overridden with command-line flags (see usage function).
DEFAULT_LOADS="256,1024,4096"
DEFAULT_THREADS="1,2,4,8"
DEFAULT_SAMPLE_SIZE=32
DEFAULT_GAP=10
DEFAULT_BEGIN=16

# Default file paths
OBJECT_DIR="./lib"
DATA_DIR="./data"
OUTPUT_CSV="${DATA_DIR}/threads_benchmark.csv"
BENCH_HARNESS_SRC="./benchmark/threads.cpp"
MAIN_LOGIC_SRC="./src/23201209.c"

# Compiler flags
CFLAGS="-Wall -Wextra -O3 -fPIC"
CXXFLAGS="-O3"
LDFLAGS="-lpthread -lbenchmark"

# --- Functions ---

#
# Prints usage information and exits.
#
function usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Compiles and benchmarks a C source file across a matrix of THREAD and LOAD values."
    echo
    echo "Options:"
    echo "  -l <list>   Comma-separated list of LOAD values (default: \"${DEFAULT_LOADS}\")"
    echo "  -t <list>   Comma-separated list of THREAD values (default: \"${DEFAULT_THREADS}\")"
    echo "  -s <num>    Sample size for the benchmark (passed as -DSAMPLE) (default: ${DEFAULT_SAMPLE_SIZE})"
    echo "  -g <num>    Gap value for the benchmark (passed as -DGAP) (default: ${DEFAULT_GAP})"
    echo "  -b <num>    Begin value for the benchmark (passed as -DBEGIN) (default: ${DEFAULT_BEGIN})"
    echo "  -o <file>   Output CSV file path (default: ${OUTPUT_CSV})"
    echo "  -h          Display this help message"
    echo
    exit 1
}

#
# Cleans up temporary files. Designed to be called on script exit.
#
function cleanup() {
    echo "--- Cleaning up temporary files ---"
    rm -f thread_bench "${DATA_DIR}/temp.csv" "${BENCH_HARNESS_SRC%.cpp}.o"
}

# --- Argument Parsing ---

# Set parameters from defaults
LOAD_STR=$DEFAULT_LOADS
THREAD_STR=$DEFAULT_THREADS
SAMPLE_SIZE=$DEFAULT_SAMPLE_SIZE
GAP=$DEFAULT_GAP
BEGIN_VAL=$DEFAULT_BEGIN

while getopts "l:t:s:g:b:o:h" opt; do
    case ${opt} in
        l) LOAD_STR=$OPTARG ;;
        t) THREAD_STR=$OPTARG ;;
        s) SAMPLE_SIZE=$OPTARG ;;
        g) GAP=$OPTARG ;;
        b) BEGIN_VAL=$OPTARG ;;
        o) OUTPUT_CSV=$OPTARG ;;
        h) usage ;;
        \?) echo "Invalid Option: -$OPTARG" >&2; usage ;;
    esac
done

# Convert comma-separated strings into Bash arrays
IFS=',' read -ra LOAD_VALUES <<< "$LOAD_STR"
IFS=',' read -ra THREAD_VALUES <<< "$THREAD_STR"

# --- Main Logic ---

function main() {
    # Trap ensures the 'cleanup' function is called when the script exits,
    # for any reason (success, error, or Ctrl+C).
    trap cleanup EXIT

    # --- Setup ---
    mkdir -p "$OBJECT_DIR" "$DATA_DIR"
    local object_files=()

    # --- Phase 1: Compile all object file variations ---
    echo "==> Compiling object file variations..."
    for l in "${LOAD_VALUES[@]}"; do
        for t in "${THREAD_VALUES[@]}"; do
            local output_file="${OBJECT_DIR}/parallel_${l}_${t}.o"
            echo "  -> Compiling for LOAD=${l}, THREADS=${t}"

            gcc ${CFLAGS} -c "${MAIN_LOGIC_SRC}" \
                -DSTRIP_MAIN \
                -DTHREAD_MIN_LOAD="${l}" \
                -DTHREAD_AMOUNT="${t}" \
                -o "${output_file}"

            object_files+=("${output_file}")
        done
    done
    echo "==> Compilation of variations finished."
    echo

    # --- Phase 2: Benchmark each object file ---

    # **EFFICIENCY GAIN**: Compile the benchmark harness only ONCE.
    echo "==> Compiling the main benchmark harness..."
    local bench_obj="${BENCH_HARNESS_SRC%.cpp}.o"
    g++ ${CXXFLAGS} -c "${BENCH_HARNESS_SRC}" -o "${bench_obj}" \
            -DSAMPLE=${SAMPLE_SIZE} \
            -DGAP=${GAP} \
            -DBEGIN=${BEGIN_VAL} \

    # Prepare the final results file
    echo "name,iterations,real_time,cpu_time,time_unit,bytes_per_second,items_per_second,label,error_occurred,error_message,threads,load" > "${OUTPUT_CSV}"
    echo "==> Running benchmarks for each object file..."

    for obj_file in "${object_files[@]}"; do
        # Recover parameters from the object filename
        local base_name=$(basename "${obj_file}")
        local params_str="${base_name#parallel_}"
        params_str="${params_str%.o}"
        local load_val="${params_str%_*}"
        local thread_val="${params_str#*_}"

        echo "  -> Benchmarking ${base_name}"

        g++ "${bench_obj}" "${obj_file}" ${CXXFLAGS} ${LDFLAGS} \
            -o thread_bench

        # Run the benchmark, redirecting its CSV output to a temporary file
        ./thread_bench --benchmark_out="${DATA_DIR}/temp.csv" --benchmark_out_format=csv

        # Process the temp file with awk to add the 'threads' and 'load' columns,
        # skipping the header line produced by the benchmark tool.
        # Append the processed result to our main CSV.
        awk -F, -v threads="${thread_val}" -v l="${load_val}" '
            BEGIN { OFS="," }
            NR > 1 { print $0, threads, l }
        ' "${DATA_DIR}/temp.csv" >> "${OUTPUT_CSV}"
    done

    echo
    echo "==> Benchmarking complete. Results are in ${OUTPUT_CSV}"
}

# Run the main function
main
