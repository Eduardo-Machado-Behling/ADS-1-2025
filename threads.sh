#!/bin/bash

# This script first compiles object files for a matrix of different
# thread and load settings, then benchmarks each one, appending
# the results to a single CSV file.

# --- Configuration ---
# LOAD_VALUES=(256 1024 4096)
LOAD_VALUES=(256 1024 4096)
THREAD_VALUES=(1 2 4 8)

OBJECT_DIR="./lib"
DATA_DIR="./data"
CSV_FILE="${DATA_DIR}/threads.csv"

BENCH_SRC="./benchmark/threads.cpp"
MAIN_SRC="./src/23201209.c"


# --- Phase 1: Compile all object file variations ---

# Ensure the directories we need exist
mkdir -p "$OBJECT_DIR" "$DATA_DIR"

# This is our list ($o in your pseudo-code), a Bash array.
object_files=()

echo "==> Compiling object files for different loads and thread counts..."

for l in "${LOAD_VALUES[@]}"; do
  for t in "${THREAD_VALUES[@]}"; do
    # Define a clear output filename for the object file
    output_file="${OBJECT_DIR}/parallel_${l}_${t}.o"

    echo "  -> Compiling for LOAD=$l, THREADS=$t"

    # Compile the source into an object file with the specific preprocessor defines.
    # Note: The stray 'ordena' from your pseudo-code was removed as it's not valid gcc syntax here.
    gcc -Wall -Wextra -O3 -c "$MAIN_SRC" \
        -DSTRIP_MAIN \
        -DTHREAD_MIN_LOAD="$l" \
        -DTHREAD_AMOUNT="$t" \
        -o "$output_file"

    # Add the newly created object file path to our list
    object_files+=("$output_file")
  done
done

echo "==> Compilation finished."
echo

# --- Phase 2: Benchmark each object file ---

# Write the header to the final CSV file, including our new columns
echo "name,iterations,real_time,cpu_time,time_unit,bytes_per_second,items_per_second ,label,error_occurred,error_message,threads,load" > "$CSV_FILE"

echo "==> Running benchmarks for each object file..."

# Loop through our list of compiled object files
for obj_file in "${object_files[@]}"; do
    #
    # --- This is the key part: Recovering $l and $t from the filename ---
    #
    # Example obj_file: "./lib/parallel_1024_8.o"
    # 1. Get just the filename: "parallel_1024_8.o"
    base_name=$(basename "$obj_file")

    # 2. Remove the prefix "parallel_" and suffix ".o" to get "1024_8"
    params_str="${base_name#parallel_}"
    params_str="${params_str%.o}"

    # 3. Extract the parts before and after the underscore '_'
    load_val="${params_str%_*}"   # Result: 1024
    thread_val="${params_str#*_}"  # Result: 8

    echo "  -> Benchmarking ${base_name} (LOAD=${load_val}, THREADS=${thread_val})"

    # Link the benchmark runner with the current object file.
    # Added -lpthread which is often required for C++ threading.
    g++ "$BENCH_SRC" "$obj_file" -O3 -lpthread -lbenchmark -o thread_bench -DSAMPLE=$1 -DGAP=$2 -DBEGIN=$3

    # Run the benchmark, saving the raw output to a temporary file
    ./thread_bench --benchmark_out="${DATA_DIR}/temp.csv" --benchmark_out_format=csv

    # Process the temp file and append it to our main CSV.
    # We use the recovered load_val and thread_val here.
    sed '1,/name,iterations/d' "${DATA_DIR}/temp.csv" | \
    awk -F, -v threads="$thread_val" -v l="$load_val" '
        BEGIN {OFS=","}
        {
            # For each line from sed, append the recovered values and print
            print $0, threads, l
        }
    ' >> "$CSV_FILE"
done

echo
echo "==> Benchmarking complete. Results are in ${CSV_FILE}"

# Clean up temporary files
rm -f thread_bench "${DATA_DIR}/temp.csv"
