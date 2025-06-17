sp=$1
e=$((2**$2))
r=$3
out='./data/data.csv'

shift 3

make
echo "arq,real_time,size" > $out
for exe in "$@"; do 
	s=$((2**$sp))
	while [ $s -le $e ]; do
		for i in $(seq 1 $r); do
			echo "[$i/$r] ./$exe $s"
			./$exe $s >> $out
		done 
		s=$((${s}*2))
	done
done
