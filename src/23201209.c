#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <threads.h>
#include <unistd.h>

#define MIN(X, Y) ((X) > (Y) ? (Y) : (X))

#ifndef THREAD_AMOUNT
#define THREAD_AMOUNT 4
#endif

#ifndef THREAD_MIN_LOAD
#define THREAD_MIN_LOAD 5
#endif

typedef struct report_t {
  int it;
  float time;
} report_t;

typedef struct {
  int b;
  int e;
} span_t;

typedef struct {
  span_t sp;
  int *arr;
  int *aux;
} thrds_args_t;

static report_t Sort(int *arr, int arrSize);
static void merge(int *arr, int *aux, span_t l, span_t r);
static void segment(span_t *res, int resSize, int amount);
static span_t mergeUp(span_t *res, span_t sp, int *arr, int *aux);
static int mergeJob(thrds_args_t *args);
static span_t __mergeSort(FILE *out, int *arr, int *aux, span_t sp);
void ParallelMergeSort(int *arr, int arrSize);

report_t Sort(int *arr, int arrSize) {
  struct timespec start, end;
  clock_gettime(CLOCK_MONOTONIC, &start);

  ParallelMergeSort(arr, arrSize);

  clock_gettime(CLOCK_MONOTONIC, &end);
  double time =
      (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;

  return (report_t){.it = arrSize, .time = time * 1e3};
}

void ParallelMergeSort(int *arr, int arrSize) {
  const int segmentsAmount =
      MIN(THREAD_AMOUNT, arrSize / (THREAD_MIN_LOAD) +
                             (arrSize % THREAD_MIN_LOAD == 0 ? 0 : 1));
  span_t segments[THREAD_AMOUNT] = {0};
  thrd_t threads[THREAD_AMOUNT];
  thrds_args_t thrdsArg[THREAD_AMOUNT];
  int *aux = malloc(arrSize * sizeof(*arr));

  segment(segments, segmentsAmount, arrSize);
  for (int i = 0; i < segmentsAmount; i++) {
    thrdsArg[i].arr = arr;
    thrdsArg[i].sp = segments[i];
    thrdsArg[i].aux = aux + thrdsArg[i].sp.b;

    thrd_create(threads + i, (thrd_start_t)(mergeJob), thrdsArg + i);
  }

  for (int i = 0; i < segmentsAmount; i++) {
    thrd_join(threads[i], NULL);
  }

  mergeUp(segments, (span_t){.b = 0, .e = segmentsAmount}, arr, aux);
  free(aux);
}

static void segment(span_t *res, int resSize, int arrSize) {
  int delta = arrSize / resSize;
  int pad = arrSize % resSize;

  for (int i = 0; i < resSize; i++) {
    res[i].b = i == 0 ? 0 : res[i - 1].e;
    res[i].e = res[i].b + delta;
    if (pad) {
      res[i].e++;
      pad--;
    }
  }
}

static span_t mergeUp(span_t *res, span_t sp, int *arr, int *aux) {
  if (sp.e - sp.b == 1) {
    // sp.b is for in the range [0, THREAD_AMOUNT)
    return res[sp.b];
  }
  const int mid = (sp.e + sp.b) / 2;

  span_t l = mergeUp(res, (span_t){.b = sp.b, .e = mid}, arr, aux);
  span_t r = mergeUp(res, (span_t){.b = mid, .e = sp.e}, arr, aux);
  merge(arr, aux, l, r);

  return (span_t){.b = l.b, .e = r.e};
}

static int mergeJob(thrds_args_t *args) {
  __mergeSort(stdout, args->arr, args->aux, args->sp);
  return 0;
}

static span_t __mergeSort(FILE *out, int *arr, int *aux, span_t sp) {
  if (sp.e - sp.b > 1) {
    const int mid = (sp.e + sp.b) / 2;
    span_t l = __mergeSort(out, arr, aux, (span_t){.b = sp.b, .e = mid});
    span_t r = __mergeSort(out, arr, aux, (span_t){.b = mid, .e = sp.e});
    merge(arr, aux, l, r);
  }

  return sp;
}

static void merge(int *arr, int *aux, span_t l, span_t r) {
  int i = 0;
  int b = l.b;

  while (l.b != l.e && r.b != r.e) {
    if (arr[l.b] < arr[r.b]) {
      aux[i++] = arr[l.b++];
    } else {
      aux[i++] = arr[r.b++];
    }
  }

  while (l.b != l.e) {
    aux[i++] = arr[l.b++];
  }

  while (r.b != r.e) {
    aux[i++] = arr[r.b++];
  }

  memcpy(arr + b, aux, i * sizeof(*aux));
}

void init(int *arr, int arrSize) {
  for (int i = 0; i < arrSize; i++) {
    arr[i] = rand();
  }
}

int isSorted(int *arr, int arrSize) {
  for (int i = 1; i < arrSize; i++) {
    if (arr[i - 1] > arr[i]) {
      return 0;
    }
  }
  return 1;
}

#ifndef STRIP_MAIN
int main(int argc, const char **argv) {
  struct timespec ts;
  timespec_get(&ts, TIME_UTC);
  srand(ts.tv_nsec);

  int s = 5;
  if (argc > 1) {
    s = atoi(argv[1]);
  }

  int sample = 1;
  if (argc > 2) {
    sample = atoi(argv[2]);
  }

  int *arr = malloc(s * sizeof(*arr));
  report_t *res = malloc(sample * sizeof(*res));

  init(arr, s);

  float mean = 0;
  for (int i = 0; i < sample; i++) {
    res[i] = Sort(arr, s);
    mean += res[i].time / sample;
  }

  if (!isSorted(arr, s)) {
    printf("ERROR\n");
  }

  printf("23201209,%d,%.4f\n", s, mean);
  free(arr);
  free(res);
  return EXIT_SUCCESS;
}
#endif
