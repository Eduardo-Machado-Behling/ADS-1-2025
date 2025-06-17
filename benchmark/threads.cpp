// benchmark_sorts.cpp
#include <benchmark/benchmark.h>

extern "C" {
void ParallelMergeSort(int *arr, size_t n);
}

const int GLOBAL_SEED = 0x1337;

// Helper to fill an array with random numbers
static void random_fill(int *arr, size_t n) {
  for (size_t i = 0; i < n; ++i) {
    arr[i] = rand();
  }
}

static void BM_ParallelMergeSort(benchmark::State &state) {
  size_t n = state.range(0);
  int *arr = (int *)malloc(n * sizeof(int));
  int *backup_arr = (int *)malloc(n * sizeof(int));

  srand(GLOBAL_SEED + n);

  for (auto _ : state) {
    state.PauseTiming();
    random_fill(arr, n);
    state.ResumeTiming();
    ParallelMergeSort(arr, n);
  }

  free(arr);
}

#ifndef GAP
#define GAP 16
#endif

#ifndef BEGIN
#define BEGIN 8
#endif

#define END 1 << (BEGIN + GAP)
#define START 1 << BEGIN

#ifndef SAMPLE
#define SAMPLE 200
#endif

BENCHMARK(BM_ParallelMergeSort)
    ->RangeMultiplier(2)
    ->Range(START, END)
    ->Repetitions(SAMPLE);

BENCHMARK_MAIN();
