// mergesort.c
#include <stdlib.h>
#include <string.h>

typedef struct {
  int b, e;
} span_t;

static void merge(int *arr, int *aux, span_t l, span_t r) {
  int i = l.b;
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
  memcpy(arr + b, aux + b, (i - b) * sizeof(*aux));
}

static void msort_recursive(int *arr, int *aux, int b, int e) {
  if (e - b <= 1)
    return;

  int m = (b + e) / 2;
  msort_recursive(arr, aux, b, m);
  msort_recursive(arr, aux, m, e);

  span_t l = {b, m};
  span_t r = {m, e};
  merge(arr, aux, l, r);
}

void WeissMergeSort(int *arr, size_t n) {
  int *aux = (int *)malloc(n * sizeof(*aux));
  if (!aux)
    return; // Handle memory error
  msort_recursive(arr, aux, 0, n);
  free(aux);
}
