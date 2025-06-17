#include <stdlib.h>

// C's qsort needs a comparison function
int cmp_int(const void *a, const void *b) {
  int ai = *(const int *)a;
  int bi = *(const int *)b;
  return (ai > bi) - (ai < bi);
}

void CSort(int *arr, int n) { qsort(arr, n, sizeof(int), cmp_int); }
