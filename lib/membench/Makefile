# -DSAMPLES=Number of times to repeat the test cycle (default 5) 
# -DNTIMES=Number of times to read/write the array per test (default 5) 
# -DSIZE=Array size (default 1073741824LL), use of LL strongly reccommended
# -DWITH_OPENMP=Is openmp enabled?

SAMPLES = 5
TIMES = 5
SIZE = 1073741824LL
OPT = O3

memory_profiler: main.c monotonic_timer.c functions.c
	gcc -$(OPT) -march=native $^ -o $@ -lm -fopenmp -DWITH_OPENMP -DFILEOUTPUT -DSAMPLES=$(SAMPLES) -DTIMES=$(TIMES) -DSIZE=$(SIZE)

clean:
	rm -f *.o memory_profiler
