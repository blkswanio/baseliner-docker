# -DSTREAM_ARRAY_SIZE=Number of elements in test arrays (default 10 million)
# -DNTIMES=Number of times to repeat the test cycle (default 10)
# -DOFFSET=Offset of test arrays, may affect array alignment (default 0)
# -DSTREAM_TYPE=Type of the test arrays (default 'double')
# -DVERBOSE=Verbose output
# set OMP_NUM_THREADS=N to set number of openmp threads (default system max)

CC = gcc
NTIMES = 500
STREAM_ARRAY_SIZE = 10000000
OFFSET = 0
STREAM_TYPE = double
OPT = O2
CFLAGS = -$(OPT) -fopenmp -DNTIMES=$(NTIMES) -DSTREAM_ARRAY_SIZE=$(STREAM_ARRAY_SIZE) -DOFFSET=$(OFFSET) -DSTREAM_TYPE=$(STREAM_TYPE) -DFILEOUTPUT

all: streamc

streamc: stream.c
	$(CC) $(CFLAGS) stream.c -lm -o streamc

mac: stream.c
	gcc-6 $(CFLAGS) stream.c -o streamc

clean:
	rm -f streamc *.o
