#include <algorithm>
#include <chrono>
#include <iostream>
#include <random>
#include <vector>

void CPPSort(int *begin, int *end) { std::sort(begin, end); }

#ifndef STRIP_MAIN
int main(int argc, char *argv[]) {
  if (argc != 2) {
    std::cerr << "Uso: " << argv[0] << " <numero_de_elementos>" << std::endl;
    return 1;
  }

  int numElementos = std::stoi(argv[1]);

  std::vector<int> dados(numElementos);

  std::random_device rd;
  std::mt19937 gen(rd());
  std::uniform_int_distribution<> distrib(1,
                                          1000); // Distribuição entre 1 e 1000

  for (int i = 0; i < numElementos; ++i)
    dados[i] = distrib(gen);

  auto inicio = std::chrono::high_resolution_clock::now();
  sort(dados.begin(), dados.end());
  auto fim = std::chrono::high_resolution_clock::now();

  auto duracao =
      std::chrono::duration_cast<std::chrono::nanoseconds>(fim - inicio);

  std::cout << "1313, " << numElementos << ", " << duracao.count() /1e6 << std::endl;

  return 0;
}
#endif
