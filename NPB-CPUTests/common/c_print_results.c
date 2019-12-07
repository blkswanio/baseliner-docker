/*****************************************************************/
/******     C  _  P  R  I  N  T  _  R  E  S  U  L  T  S     ******/
/*****************************************************************/
#include <stdlib.h>
#include <stdio.h>
#ifdef _OPENMP
#include <omp.h>
#endif

void c_print_results( char   *name,
                      char   class,
                      int    n1, 
                      int    n2,
                      int    n3,
                      int    niter,
                      double t,
                      double mops,
		      char   *optype,
                      int    passed_verification,
                      char   *npbversion,
                      char   *compiletime,
                      char   *cc,
                      char   *clink,
                      char   *c_lib,
                      char   *c_inc,
                      char   *cflags,
                      char   *clinkflags )
{
    int num_threads, max_threads;


    max_threads = 1;
    num_threads = 1;

/*   figure out number of threads used */
#ifdef _OPENMP
    max_threads = omp_get_max_threads();
#pragma omp parallel shared(num_threads)
{
    #pragma omp master
    num_threads = omp_get_num_threads();
}
#endif


    printf( "\n\n %s Benchmark Completed\n", name ); 

    printf( " Class           =                        %c\n", class );

    if( n3 == 0 ) {
        long nn = n1;
        if ( n2 != 0 ) nn *= n2;
        printf( " Size            =             %12ld\n", nn );   /* as in IS */
    }
    else
        printf( " Size            =             %4dx%4dx%4d\n", n1,n2,n3 );

    printf( " Iterations      =             %12d\n", niter );
 
    printf( " Time in seconds =             %12.2f\n", t );

    printf( " Total threads   =             %12d\n", num_threads);

    printf( " Avail threads   =             %12d\n", max_threads);

    if (num_threads != max_threads) 
        printf( " Warning: Threads used differ from threads available\n");

    printf( " Mop/s total     =             %12.2f\n", mops );

    printf( " Mop/s/thread    =             %12.2f\n",
           mops/(double)num_threads );

    printf( " Operation type  = %24s\n", optype);

    if( passed_verification < 0 ) {
        printf( " Verification    =            NOT PERFORMED\n" );
    } else if( passed_verification ) {
        printf( " Verification    =               SUCCESSFUL\n" );
    } else {
        printf( " Verification    =             UNSUCCESSFUL\n" );
    }

    printf( " Version         =             %12s\n", npbversion );

    printf( " Compile date    =             %12s\n", compiletime );

    printf( "\n Compile options:\n" );

    printf( "    CC           = %s\n", cc );

    printf( "    CLINK        = %s\n", clink );

    printf( "    C_LIB        = %s\n", c_lib );

    printf( "    C_INC        = %s\n", c_inc );

    printf( "    CFLAGS       = %s\n", cflags );

    printf( "    CLINKFLAGS   = %s\n", clinkflags );

    printf( "\n\n" );
    printf( " Please send all errors/feedbacks to:\n\n" );
    printf( " NPB Development Team\n" );
    printf( " npb@nas.nasa.gov\n\n\n" );
/*    printf( " Please send the results of this run to:\n\n" );
    printf( " NPB Development Team\n" );
    printf( " Internet: npb@nas.nasa.gov\n \n" );
    printf( " If email is not available, send this to:\n\n" );
    printf( " MS T27A-1\n" );
    printf( " NASA Ames Research Center\n" );
    printf( " Moffett Field, CA  94035-1000\n\n" );
    printf( " Fax: 650-604-3957\n\n" ); */
    printf( "testname,class,size,iterations,exec_time,total_threads,"\
            "avail_threads,mops_total,mops_per_thread,"\
            "operation_type,verification,version,compile_date,"\
            "compiler,linker,lib,inc,flags,linkflags,rand\n");
    printf( "%s,", name );
    printf( "%c,", class );
    if( n3 == 0 ) {
        long nn = n1;
        if ( n2 != 0 ) nn *= n2;
        printf( "%12ld,", nn );   /* as in IS */
    }
    else
        printf( "%4dx%4dx%4d,", n1,n2,n3 );
    printf( "%12d,", niter );
    printf( "%12.3f,", t );
    printf( "%12d,", num_threads);
    printf( "%12d,", max_threads);
    printf( "%12.3f,", mops );
    printf( "%12.3f,", mops/(double)num_threads );
    printf( "%s,", optype);
    if( passed_verification < 0 )
        printf( "NOT PERFORMED," );
    else if( passed_verification )
        printf( "SUCCESSFUL," );
    else
        printf( "UNSUCCESSFUL," );
    printf( "%s,", npbversion );
    printf( "%s,", compiletime );
    printf( "%s,", cc );
    printf( "%s,", clink );
    printf( "%s,", c_lib );
    printf( "%s,", c_inc );
    printf( "%s,", cflags );
    printf( "%s,", clinkflags );
    printf( "(none)");
} 