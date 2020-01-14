SHELL=/bin/sh
BENCHMARK=is
BENCHMARKU=IS

include ../config/make.def

include ../sys/make.common

OBJS = is.o \
       ${COMMON}/c_print_results.o \
       ${COMMON}/c_timers.o \
       ${COMMON}/c_wtime.o


${PROGRAM}: config ${OBJS}
ifeq (${CLASS},D)
	${CLINK} ${CLINKFLAGS} -mcmodel=large -o ${PROGRAM} ${OBJS} ${C_LIB}
else
	${CLINK} ${CLINKFLAGS} -o ${PROGRAM} ${OBJS} ${C_LIB}
endif

.c.o:
ifeq (${CLASS},D)
	${CCOMPILE} $< -mcmodel=large
else
	${CCOMPILE} $<
endif

is.o:             is.c  npbparams.h

clean:
	- rm -f *.o *~ mputil*
	- rm -f npbparams.h core
	- if [ -d rii_files ]; then rm -r rii_files; fi
