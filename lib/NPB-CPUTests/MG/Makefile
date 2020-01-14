SHELL=/bin/sh
BENCHMARK=mg
BENCHMARKU=MG

include ../config/make.def

OBJS = mg.o ${COMMON}/print_results.o  \
       ${COMMON}/${RAND}.o ${COMMON}/timers.o ${COMMON}/wtime.o

include ../sys/make.common


${PROGRAM}: config ${OBJS}
ifeq (${CLASS},C)
	${FLINK} ${FLINKFLAGS} -mcmodel=large -o ${PROGRAM} ${OBJS} ${F_LIB}
else
	${FLINK} ${FLINKFLAGS} -o ${PROGRAM} ${OBJS} ${F_LIB}
endif

mg.o:		mg.f globals.h npbparams.h
ifeq (${CLASS},C)
	${FCOMPILE} -mcmodel=large mg.f
else
	${FCOMPILE} mg.f
endif



clean:
	- rm -f *.o *~ 
	- rm -f npbparams.h core
	- if [ -d rii_files ]; then rm -r rii_files; fi
