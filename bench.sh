echo "Running THREADS=$1, TLOAD=$2, SMAPLE=$3, GAP=$4, BEGIN=$5"
make clean
make THREADS=$1 TLOAD=$2
g++ ./benchmark/main.cpp ./lib/mergesort.o ./lib/23201209.o ./lib/Cormen.o ./lib/1313.o ./lib/qsort.o -lbenchmark -lpthread -O2 -o bench_sorts -DSAMPLE=$3 -DGAP=$4 -DBEGIN=$5
./bench_sorts --benchmark_out=./data/output.csv --benchmark_out_format=csv
mv ./data/output.csv "./data/$1_$2_$3_$4.csv"
rm ./bench_sorts
