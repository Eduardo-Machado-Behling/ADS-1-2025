#!/bin/bash

# ==============================================================================
#
#                            Benchmark Runner Script
#
# Description:
#   This script compiles and runs a series of specified executable programs
#   to benchmark their performance. It iterates through a range of input sizes
#   (powers of 2), runs each executable multiple times for each size, and
#   appends the output to a single CSV file.
#
#   The script assumes that the executables it runs will print their results
#   to standard output in a CSV format that matches the header. For example:
#   "my_program_name,8192,12345.67"
#
# ==============================================================================


# --- Script Configuration & Safety ---

# Exit immediately if a command exits with a non-zero status. This prevents
# running old binaries if the 'make' command fails, for example.
set -e

# --- Default Parameters ---

# These values will be used if not provided via command-line flags.
START_POWER=10      # The starting size will be 2^START_POWER
END_POWER=20        # The final size will be 2^END_POWER
REPETITIONS=5       # Number of times to run each executable for each size
OUTPUT_FILE="./data/data.csv" # Default output file path

# --- Functions ---

#
# Prints the usage information for the script and exits.
#
function usage() {
  echo "Usage: $0 [OPTIONS] <executable1> [executable2] ..."
  echo
  echo "Runs performance benchmarks for one or more executable files."
  echo
  echo "Options:"
  echo "  -p <num>    Starting power of 2 for input size (default: ${START_POWER})"
  echo "  -e <num>    Ending power of 2 for input size (default: ${END_POWER})"
  echo "  -r <num>    Number of repetitions for each run (default: ${REPETITIONS})"
  echo "  -o <file>   Output CSV file path (default: ${OUTPUT_FILE})"
  echo "  -h          Display this help message"
  echo
  exit 1
}

# --- Argument Parsing ---

# Parse command-line options using a while loop and case statement.
# This is more robust and user-friendly than relying on argument order ($1, $2, ...).
while getopts "p:e:r:o:h" opt; do
  case ${opt} in
    p)
      START_POWER=$OPTARG
      ;;
    e)
      END_POWER=$OPTARG
      ;;
    r)
      REPETITIONS=$OPTARG
      ;;
    o)
      OUTPUT_FILE=$OPTARG
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid Option: -$OPTARG" 1>&2
      usage
      ;;
  esac
done

# 'shift' consumes the options that have been processed, so that $@ now
# contains only the remaining arguments (the list of executables).
shift $((OPTIND -1))

# --- Pre-run Checks ---

# Check if at least one executable program was provided.
if [ "$#" -eq 0 ]; then
  echo "Error: No executable files provided."
  usage
fi

# --- Main Execution ---

# 1. Compile the source code. The 'set -e' at the top will cause the
#    script to exit if this 'make' command fails.
echo "--- Compiling source code ---"
make
echo

# 2. Prepare the output file.
#    - Create the directory if it doesn't exist (`mkdir -p`).
#    - Write the CSV header, overwriting any previous file content.
echo "--- Preparing output file: ${OUTPUT_FILE} ---"
mkdir -p "$(dirname "${OUTPUT_FILE}")"
echo "arq,size,real_time" > "${OUTPUT_FILE}"
echo

# 3. Calculate the start and end sizes based on the powers.
start_size=$((2**START_POWER))
end_size=$((2**END_POWER))

echo "--- Starting Benchmarks ---"
echo "Configuration:"
echo "  Input Size Range: ${start_size} to ${end_size}"
echo "  Repetitions/Run: ${REPETITIONS}"
echo "  Executables: $@"
echo

# 4. Loop through each executable provided on the command line.
for exe in "$@"; do
  # Initialize the current size for this executable.
  current_size=${start_size}

  # Loop from the starting size to the ending size, doubling the size each time.
  while [ ${current_size} -le ${end_size} ]; do

    # Repeat the benchmark for the current size to get a stable average.
    for i in $(seq 1 ${REPETITIONS}); do
      # Print progress to standard error (stderr) to keep stdout clean for redirection.
      echo "[$i/${REPETITIONS}] Running: ./${exe} ${current_size}" >&2

      # Run the executable and append its standard output directly to the CSV file.
      ./${exe} ${current_size} >> "${OUTPUT_FILE}"
    done

    # Double the size for the next iteration.
    current_size=$((current_size * 2))
  done
done

echo
echo "--- Benchmark complete. Data saved to ${OUTPUT_FILE} ---"
