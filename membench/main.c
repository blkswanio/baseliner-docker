// Copyright 2013 Alex Reece.  Modified by Aleksander Maricq (2016).
//
// A simple memory bandwidth profiler.
//
// Each of the read_memory_* functions reads from a 1GB array. Each of the
// write_memory_* writes to the 1GB array. The goal is to get the max memory
// bandwidth as follows: 
// MaxBW (MB/s) = ((DDR clock speed (MHz) * width (bits) * nchannels)/(8 * BYTES_PER_MB))

#include <assert.h>
#include <math.h>
#ifdef WITH_OPENMP
#include <omp.h>
#endif  // WITH_OPENMP
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#include "./functions.h"
#include "./monotonic_timer.h"

#ifndef SAMPLES
#define SAMPLES 5
#endif // SAMPLES

#ifndef TIMES
#define TIMES 5
#endif // TIMES

#define BYTES_PER_GiB (1024*1024*1024LL)
#define BYTES_PER_MB 1000000

#ifndef SIZE
#define SIZE (1*BYTES_PER_GiB)
#endif // SIZE

#define PAGE_SIZE (1<<12)

// This must be at least 32 byte aligned to make some AVX instructions happy.
// Have PAGE_SIZE buffering so we don't have to do math for prefetching.
char array[SIZE + PAGE_SIZE] __attribute__((aligned (32)));

// Define FILE variable globally
FILE *outfile = NULL;

// Compute the bandwidth in MB/s.  
// AMARICQ - Was previously GiB/s, can switch back if needed.
static inline double to_bw(size_t bytes, double secs) {
  double size_bytes = (double) bytes;
  double size_mb = size_bytes / ((double) BYTES_PER_MB);
  return size_mb / secs;
}

#ifdef WITH_OPENMP
// Time a function, printing out time to perform the memory operation and
// the computed memory bandwidth. Use openmp to do threading (set environment
// variable OMP_NUM_THREADS to control threads use.
#define timefunp(f) timeitp(f, #f)
void timeitp(void (*function)(void*, size_t), char* name) {
  double min = INFINITY;
  // AMARICQ - add max, mean, delta, delta2, and M2 to calculate more complete statistics
  double max = 0;
  double mean = 0;
  double delta = 0;
  double delta2 = 0;
  double M2 = 0;
  size_t i;
  for (i = 0; i < SAMPLES; i++) {
    double before, after, total;

    assert(SIZE % omp_get_max_threads() == 0);

    size_t chunk_size = SIZE / omp_get_max_threads();
#pragma omp parallel
    {
#pragma omp barrier
#pragma omp master
      before = monotonic_time();
      int j;
      for (j = 0; j < TIMES; j++) {
	function(&array[chunk_size * omp_get_thread_num()], chunk_size);
      }
#pragma omp barrier
#pragma omp master
      after = monotonic_time();
    }

    // AMARICQ - Convert to bw before collecting statistics
    total = to_bw(SIZE * TIMES, after - before);
    
    // Use Online algorithm for variance to get standard deviation
    // https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Online_algorithm
    delta = total - mean;
    mean += delta / (i+1);
    delta2 = total - mean;
    M2 += delta * delta2;
    if (total < min) {
      min = total;
    }
    if (total > max) {
      max = total;
    }
  }
  double stdev = sqrt(M2 / SAMPLES);
  printf("%28s_omp: %5.2f MB/s\t\t%5.2f MB/s\t\t%5.2f MB/s\t\t%3.2f MB/s\n", name, max, min, mean, stdev);

#ifdef FILEOUTPUT
  if (outfile != NULL) {
    fprintf(outfile, "%.2f,%.2f,%.2f,%.2f,", max, min, mean, stdev);
  }
#endif
}
#endif  // WITH_OPENMP

// Time a function, printing out time to perform the memory operation and
// the computed memory bandwidth.
#define timefun(f) timeit(f, #f)
void timeit(void (*function)(void*, size_t), char* name) {
  double min = INFINITY;
  // AMARICQ - add max, mean, delta, delta2, and M2 to calculate more complete statistics
  double max = 0;
  double mean = 0;
  double delta = 0;
  double delta2 = 0;
  double M2 = 0;
  size_t i;
  for (i = 0; i < SAMPLES; i++) {
    double before, after, total;

    before = monotonic_time();
    int j;
    for (j = 0; j < TIMES; j++) {
      function(array, SIZE);
    }
    after = monotonic_time();

    // AMARICQ - Convert to bw before collecting statistics
    total = to_bw(SIZE * TIMES, after - before);
    
    // Use Online algorithm for variance to get standard deviation
    // https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Online_algorithm
    delta = total - mean;
    mean += delta / (i+1);
    delta2 = total - mean;
    M2 += delta * delta2;
    if (total < min) {
      min = total;
    }
    if (total > max) {
      max = total;
    }
  }
  double stdev = sqrt(M2 / SAMPLES);
  printf("%32s: %5.2f MB/s\t\t%5.2f MB/s\t\t%5.2f MB/s\t\t%3.2f MB/s\n", name, max, min, mean, stdev);

#ifdef FILEOUTPUT
  if (outfile != NULL) {
    fprintf(outfile, "%.2f,%.2f,%.2f,%.2f,", max, min, mean, stdev);
  }
#endif
}

int main() {
  // AMARICQ - Header
  printf("===========================================\n");
  printf("= Memory Bandwidth Profiler by Alex Reese =\n");
  printf("===========================================\n");
  
  // AMARICQ - Print test information
  printf("Number of Samples:\t\t%d\n", SAMPLES);
  printf("Number of Loops per Sample:\t%d\n", TIMES);
  printf("Array Size per Loop:\t\t%lld Bytes\n", SIZE);
  // AMARICQ - Print clock information
  printf("Timer:\t\t\t\t");
#if _POSIX_TIMERS > 0 && defined(_POSIX_MONOTONIC_CLOCK)
  printf("CLOCK_MONOTONIC (POSIX)\n");
#elif defined(__APPLE__)
  printf("mach_absolute_time() (Mac)\n");
#elif defined(_MSC_VER)
  printf("QueryPerformanceFrequency (Windows)\n");
#else
  printf("rdtscp (Other Platform)\n");
#endif

  // AMARICQ - Print extension information
  printf("AVX:\t\t\t\t");
#ifdef __AVX__
  printf("enabled\n");
#else
  printf("disabled\n");
#endif // AVX
  printf("SSE4.1:\t\t\t\t");
#ifdef __SSE4_1__
  printf("enabled\n");
#else
  printf("disabled\n");
#endif // SSE4.1
  printf("OPENMP:\t\t\t\t");
#ifdef WITH_OPENMP
  printf("enabled\n");
  printf("OPENMP Number of Threads:\t");
  int k = 0;
#pragma omp parallel
#pragma omp atomic 
  k++;
  int num_threads = k;
  printf("%i\n", num_threads);
#else
  printf("disabled\n");
#endif // WITH_OPENMP
  printf("lodsq/stosq:\t\t\t");
#ifdef __x86_64__
  printf("enabled\n");
#else
  printf("disabled\n");
#endif // x86_64
  printf("\n");
  printf("%28s\t  Max Bandwidth\t\tMin Bandwidth\t\tMean Bandwidth\t\tStandard Deviation\n", "Test Name");
  
  // Setup File Output and print header
#ifdef FILEOUTPUT
  outfile = fopen("memory_profiler_out.csv", "w");
  if (outfile != NULL) {
#ifdef __x86_64__
    fprintf(outfile, "read_memory_rep_lodsq_max,read_memory_rep_lodsq_min,read_memory_rep_lodsq_mean,read_memory_rep_lodsq_stdev,");
#endif // x86_64
    fprintf(outfile, "read_memory_loop_max,read_memory_loop_min,read_memory_loop_mean,read_memory_loop_stdev,");
#ifdef __SSE4_1__
    fprintf(outfile, "read_memory_sse_max,read_memory_sse_min,read_memory_sse_mean,read_memory_sse_stdev,");
#endif // SSE4.1
#ifdef __AVX__
    fprintf(outfile, "read_memory_avx_max,read_memory_avx_min,read_memory_avx_mean,read_memory_avx_stdev,");
    fprintf(outfile, "read_memory_prefetch_avx_max,read_memory_prefetch_avx_min,read_memory_prefetch_avx_mean,read_memory_prefetch_avx_stdev,");
#endif // AVX

    fprintf(outfile, "write_memory_loop_max,write_memory_loop_min,write_memory_loop_mean,write_memory_loop_stdev,");
#ifdef __x86_64__
    fprintf(outfile, "write_memory_rep_stosq_max,write_memory_rep_stosq_min,write_memory_rep_stosq_mean,write_memory_rep_stosq_stdev,");
#endif // x86_64
#ifdef __SSE4_1__
    fprintf(outfile, "write_memory_sse_max,write_memory_sse_min,write_memory_sse_mean,write_memory_sse_stdev,");
    fprintf(outfile, "write_memory_nontemporal_sse_max,write_memory_nontemporal_sse_min,write_memory_nontemporal_sse_mean,write_memory_nontemporal_sse_stdev,");
#endif // SSE4.1
#ifdef __AVX__
    fprintf(outfile, "write_memory_avx_max,write_memory_avx_min,write_memory_avx_mean,write_memory_avx_stdev,");
    fprintf(outfile, "write_memory_nontemporal_avx_max,write_memory_nontemporal_avx_min,write_memory_nontemporal_avx_mean,write_memory_nontemporal_avx_stdev,");
#endif // AVX
    fprintf(outfile, "write_memory_memset_max,write_memory_memset_min,write_memory_memset_mean,write_memory_memset_stdev,");

#ifdef WITH_OPENMP

#ifdef __x86_64__
    fprintf(outfile, "read_memory_rep_lodsq_omp_max,read_memory_rep_lodsq_omp_min,read_memory_rep_lodsq_omp_mean,read_memory_rep_lodsq_omp_stdev,");
#endif // x86_64
    fprintf(outfile, "read_memory_loop_omp_max,read_memory_loop_omp_min,read_memory_loop_omp_mean,read_memory_loop_omp_stdev,");
#ifdef __SSE4_1__
    fprintf(outfile, "read_memory_sse_omp_max,read_memory_sse_omp_min,read_memory_sse_omp_mean,read_memory_sse_omp_stdev,");
#endif // SSE4.1
#ifdef __AVX__
    fprintf(outfile, "read_memory_avx_omp_max,read_memory_avx_omp_min,read_memory_avx_omp_mean,read_memory_avx_omp_stdev,");
    fprintf(outfile, "read_memory_prefetch_avx_omp_max,read_memory_prefetch_avx_omp_min,read_memory_prefetch_avx_omp_mean,read_memory_prefetch_avx_omp_stdev,");
#endif // AVX

    fprintf(outfile, "write_memory_loop_omp_max,write_memory_loop_omp_min,write_memory_loop_omp_mean,write_memory_loop_omp_stdev,");
#ifdef __x86_64__
    fprintf(outfile, "write_memory_rep_stosq_omp_max,write_memory_rep_stosq_omp_min,write_memory_rep_stosq_omp_mean,write_memory_rep_stosq_omp_stdev,");
#endif // x86_64
#ifdef __SSE4_1__
    fprintf(outfile, "write_memory_sse_omp_max,write_memory_sse_omp_min,write_memory_sse_omp_mean,write_memory_sse_omp_stdev,");
    fprintf(outfile, "write_memory_nontemporal_sse_omp_max,write_memory_nontemporal_sse_omp_min,write_memory_nontemporal_sse_omp_mean,write_memory_nontemporal_sse_omp_stdev,");
#endif // SSE4.1
#ifdef __AVX__
    fprintf(outfile, "write_memory_avx_omp_max,write_memory_avx_omp_min,write_memory_avx_omp_mean,write_memory_avx_omp_stdev,");
    fprintf(outfile, "write_memory_nontemporal_avx_omp_max,write_memory_nontemporal_avx_omp_min,write_memory_nontemporal_avx_omp_mean,write_memory_nontemporal_avx_omp_stdev,");
#endif // AVX
    fprintf(outfile, "write_memory_memset_omp_max,write_memory_memset_omp_min,write_memory_memset_omp_mean,write_memory_memset_omp_stdev,");
    fprintf(outfile, "omp_nthreads_used,");
#endif // OPENMP
    fprintf(outfile, "units\n");
  }
#endif // FILEOUTPUT

  memset(array, 0xFF, SIZE);  // un-ZFOD the page.
  * ((uint64_t *) &array[SIZE]) = 0;

  // TODO(awreece) iopl(0) and cli/sti?

#ifdef __x86_64__
  timefun(read_memory_rep_lodsq);
#endif
  timefun(read_memory_loop);
#ifdef __SSE4_1__
  timefun(read_memory_sse);
#endif
#ifdef __AVX__
  timefun(read_memory_avx);
  timefun(read_memory_prefetch_avx);
#endif

  timefun(write_memory_loop);
#ifdef __x86_64__
  timefun(write_memory_rep_stosq);
#endif
#ifdef __SSE4_1__
  timefun(write_memory_sse);
  timefun(write_memory_nontemporal_sse);
#endif
#ifdef __AVX__
  timefun(write_memory_avx);
  timefun(write_memory_nontemporal_avx);
#endif
  timefun(write_memory_memset);

#ifdef WITH_OPENMP

  memset(array, 0xFF, SIZE);  // un-ZFOD the page.
  * ((uint64_t *) &array[SIZE]) = 0;

#ifdef __x86_64__
  timefunp(read_memory_rep_lodsq);
#endif
  timefunp(read_memory_loop);
#ifdef __SSE4_1__
  timefunp(read_memory_sse);
#endif
#ifdef __AVX__
  timefunp(read_memory_avx);
  timefunp(read_memory_prefetch_avx);
#endif

  timefunp(write_memory_loop);
#ifdef __x86_64__
  timefunp(write_memory_rep_stosq);
#endif
#ifdef __SSE4_1__
  timefunp(write_memory_sse);
  timefunp(write_memory_nontemporal_sse);
#endif
#ifdef __AVX__
  timefunp(write_memory_avx);
  timefunp(write_memory_nontemporal_avx);
#endif
  timefunp(write_memory_memset);

#endif  // WITH_OPENMP

#ifdef FILEOUTPUT
  if (outfile != NULL) {
#ifdef WITH_OPENMP
    fprintf (outfile, "%i,",num_threads); // Number of Threads used
#endif // WITH_OPENMP
    fprintf(outfile, "MB/s");
    fclose(outfile);
  }
#endif // FILEOUTPUT
  return 0;
}
