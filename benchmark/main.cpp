// benchmark_sorts.cpp
#include <benchmark/benchmark.h>

#include <cstdlib>
#include <cstring>
#include <ctime>

void CPPSort(int *begin, int *end);
extern "C" {
void WeissMergeSort(int *arr, size_t n);
void ParallelMergeSort(int *arr, size_t n);
void CormenQuickSort(int *arr, int b, int e);
void CSort(int *arr, int e);
}
// Your MergeSort
//

const int GLOBAL_SEED = clock();

// Helper to fill an array with random numbers
static void random_fill(int *arr, size_t n) {
  for (size_t i = 0; i < n; ++i) {
    arr[i] = rand();
  }
}

// Benchmark MergeSort
static void BM_MergeSort(benchmark::State &state) {
  size_t n = state.range(0);
  int *arr = (int *)malloc(n * sizeof(int));

  srand(GLOBAL_SEED + n);

  for (auto _ : state) {
    state.PauseTiming();
    random_fill(arr, n);
    state.ResumeTiming();
    WeissMergeSort(arr, n);
  }

  free(arr);
}

static void BM_QuickSort(benchmark::State &state) {
  size_t n = state.range(0);
  int *arr = (int *)malloc(n * sizeof(int));

  srand(GLOBAL_SEED + n);

  for (auto _ : state) {
    state.PauseTiming();
    random_fill(arr, n);
    state.ResumeTiming();
    CormenQuickSort(arr, 0, n);
  }

  free(arr);
}

static void BM_CPPSort(benchmark::State &state) {
  size_t n = state.range(0);
  int *arr = (int *)malloc(n * sizeof(int));

  srand(GLOBAL_SEED + n);

  for (auto _ : state) {
    state.PauseTiming();
    random_fill(arr, n);
    state.ResumeTiming();

    CPPSort(arr, arr + n);
  }

  free(arr);
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

// Benchmark qsort
static void BM_Qsort(benchmark::State &state) {
  size_t n = state.range(0);
  int *arr = (int *)malloc(n * sizeof(int));

  srand(GLOBAL_SEED + n);

  for (auto _ : state) {
    state.PauseTiming();
    random_fill(arr, n);
    state.ResumeTiming();
    CSort(arr, n);
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

// Register both benchmarks
BENCHMARK(BM_MergeSort)
    ->RangeMultiplier(2)
    ->Range(START, END)
    ->Repetitions(SAMPLE);
BENCHMARK(BM_Qsort)->RangeMultiplier(2)->Range(START, END)->Repetitions(SAMPLE);
BENCHMARK(BM_ParallelMergeSort)
    ->RangeMultiplier(2)
    ->Range(START, END)
    ->Repetitions(SAMPLE);
BENCHMARK(BM_QuickSort)
    ->RangeMultiplier(2)
    ->Range(START, END)
    ->Repetitions(SAMPLE);
BENCHMARK(BM_CPPSort)
    ->RangeMultiplier(2)
    ->Range(START, END)
    ->Repetitions(SAMPLE);

BENCHMARK_MAIN();
