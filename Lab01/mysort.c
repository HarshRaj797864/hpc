/*
 * mysort.c - Lab 01: Performance Profiling and Optimization using GPROF and PERF
 *
 * Scenario:
 *   A weather analytics company stores ~50 years of daily temperature readings
 *   (50 * 365 = 18,250 records) and sorts them. The sort is "slower than
 *   expected". This program implements the current baseline (Bubble Sort) and
 *   the proposed replacement (Quick Sort), sorts *identical* copies of the same
 *   dataset with each, and reports the execution time of both.
 *
 * Data model:
 *   Temperatures are stored as `int` in MILLIDEGREES Celsius (e.g. 21374 =
 *   21.374 C). Integer storage keeps the comparison in the sort a single
 *   integer compare - the thing we actually want to profile - while the
 *   0.001 C resolution keeps duplicate keys rare even at N = 4,000,000.
 *   (That matters: the Lomuto partition below degrades towards O(n^2) on runs
 *   of equal keys, so a coarse resolution would silently change what we are
 *   measuring.)
 *
 *   The generator uses a triangular annual cycle plus pseudo-random noise. It
 *   deliberately avoids <math.h> so that the exact compile line given in the
 *   lab sheet - `gcc -O0 -pg mysort.c -o mysort` - links without -lm.
 *
 * Build (as per lab sheet):
 *   gcc -O0 -pg mysort.c -o mysort
 *   gcc -O2 -pg mysort.c -o mysort_O2
 *   gcc -O3 -pg mysort.c -o mysort_O3
 *
 * Optional builds:
 *   gcc -O2 -DCOUNTERS mysort.c -o mysort_counters   # count comparisons/swaps
 *   gcc -O2 -fopenmp   mysort.c -o mysort_omp        # + parallel quicksort
 *
 * Usage:
 *   ./mysort [N] [options]
 *     N               number of records to sort   (default 18250)
 *     --quick-only    skip Bubble Sort (use for large N; bubble is O(n^2))
 *     --bubble-only   skip Quick Sort
 *     --parallel      also run the OpenMP quicksort (needs -fopenmp)
 *     --csv           emit one machine-readable CSV row per algorithm
 *     --seed S        RNG seed (default 12345, so runs are reproducible)
 *     --repeat R      time R runs and report the best (default 1)
 *
 * Author: Harsh Raj
 */

#define _POSIX_C_SOURCE 199309L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef _OPENMP
#include <omp.h>
#endif

#define DEFAULT_N 18250 /* 50 years x 365 days */

/* ------------------------------------------------------------------ */
/* Optional operation counters.                                        */
/* Compiled out by default: incrementing a global in the inner loop     */
/* would itself distort the profile we are trying to measure.           */
/* ------------------------------------------------------------------ */
#ifdef COUNTERS
static unsigned long long g_cmp;
static unsigned long long g_swap;
#define CMP_TICK() (g_cmp++)
#define SWAP_TICK() (g_swap++)
#else
#define CMP_TICK() ((void)0)
#define SWAP_TICK() ((void)0)
#endif

/* ------------------------------------------------------------------ */
/* Timing helpers                                                      */
/* ------------------------------------------------------------------ */

/* CPU time consumed by this process (what clock() reports). */
static double cpu_seconds(void)
{
    return (double)clock() / (double)CLOCKS_PER_SEC;
}

/* Wall-clock time from a monotonic source (immune to NTP steps). */
static double wall_seconds(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

/* ------------------------------------------------------------------ */
/* Dataset generation                                                  */
/* ------------------------------------------------------------------ */

/*
 * Simulated daily temperature in millidegrees Celsius.
 *
 * Annual cycle: a triangular wave over a 365-day year, coldest in mid-January
 * (day 15), warmest in mid-July (day 197), swinging between 3 C and 27 C.
 * Daily weather noise: the mean of three uniform draws (a crude but cheap
 * approximation of a normal distribution) spanning about +/- 8 C.
 *
 * Net range is roughly -5 C .. +35 C => ~40,000 distinct integer keys.
 */
static void generate_temperatures(int *arr, int n, unsigned int seed)
{
    const int cold_day = 15;      /* coldest day of year          */
    const int half_year = 182;    /* days from coldest to hottest */
    const int min_milli = 3000;   /*  3.000 C seasonal minimum    */
    const int max_milli = 27000;  /* 27.000 C seasonal maximum    */
    int i;

    srand(seed);

    for (i = 0; i < n; i++) {
        int doy = i % 365;
        int dist, seasonal, noise;

        /* Triangular wave: distance from the coldest day, folded at half-year. */
        dist = doy - cold_day;
        if (dist < 0)
            dist += 365;
        if (dist > half_year)
            dist = 365 - dist;
        if (dist < 0)
            dist = 0;

        seasonal = min_milli + (int)((long)(max_milli - min_milli) * dist / half_year);

        /* Mean of three uniform draws in [-8000, +8000] millidegrees. */
        noise = (rand() % 16001 - 8000) + (rand() % 16001 - 8000) + (rand() % 16001 - 8000);
        noise /= 3;

        arr[i] = seasonal + noise;
    }
}

/* Verify the sort actually worked. A fast sort that returns wrong data is
 * not a fast sort. */
static int is_sorted(const int *arr, int n)
{
    int i;
    for (i = 1; i < n; i++)
        if (arr[i - 1] > arr[i])
            return 0;
    return 1;
}

/* ------------------------------------------------------------------ */
/* Shared primitive                                                    */
/* ------------------------------------------------------------------ */

/* Swap two elements.
 * Deliberately a real function (not a macro): at -O0 it stays a genuine call,
 * which is exactly what makes it show up as a hotspot in the -O0 gprof report
 * and then vanish - inlined - at -O2/-O3. That contrast is one of the results
 * this lab is meant to produce. */
void swap(int *a, int *b)
{
    int temp = *a;
    *a = *b;
    *b = temp;
    SWAP_TICK();
}

/* ------------------------------------------------------------------ */
/* Baseline: Bubble Sort - O(n^2)                                      */
/* ------------------------------------------------------------------ */

/*
 * Textbook bubble sort, with the standard "no swaps => already sorted" early
 * exit. On the random data used here the early exit essentially never fires
 * before the final pass, so the measured cost stays the full O(n^2).
 */
void bubbleSort(int arr[], int n)
{
    int i, j;

    for (i = 0; i < n - 1; i++) {
        int swapped = 0;

        for (j = 0; j < n - 1 - i; j++) {
            CMP_TICK();
            if (arr[j] > arr[j + 1]) {
                swap(&arr[j], &arr[j + 1]);
                swapped = 1;
            }
        }

        if (!swapped)
            break;
    }
}

/* ------------------------------------------------------------------ */
/* Optimized: Quick Sort - O(n log n) average                          */
/* ------------------------------------------------------------------ */

/*
 * Lomuto partition scheme, last element as pivot - kept exactly as supplied in
 * the lab brief so the profile reflects the code under study.
 *
 * Known weakness, discussed in the report: on already-sorted or reverse-sorted
 * input this pivot choice gives O(n^2) time and O(n) recursion depth. The
 * benchmark below sorts randomly generated data, where the expected depth is
 * about 2*log2(n) (~40 levels at N = 1,000,000).
 */
int partition(int arr[], int low, int high)
{
    int pivot = arr[high];
    int i = (low - 1);
    int j;

    for (j = low; j < high; j++) {
        CMP_TICK();
        if (arr[j] < pivot) {
            i++;
            swap(&arr[i], &arr[j]);
        }
    }
    swap(&arr[i + 1], &arr[high]);
    return (i + 1);
}

/* QuickSort recursive function. */
void quickSort(int arr[], int low, int high)
{
    if (low < high) {
        int pi = partition(arr, low, high);
        quickSort(arr, low, pi - 1);
        quickSort(arr, pi + 1, high);
    }
}

/* ------------------------------------------------------------------ */
/* Parallel Quick Sort (OpenMP tasks) - feasibility experiment         */
/* ------------------------------------------------------------------ */
#ifdef _OPENMP
/*
 * The two recursive calls in quickSort touch disjoint halves of the array, so
 * they are independent and can run as separate tasks. Two guards keep this
 * from collapsing under task-creation overhead:
 *   - depth: stop spawning once we have roughly as many tasks as cores;
 *   - CUTOFF: small subarrays are sorted serially.
 * The partition step itself remains sequential, which is what ultimately caps
 * the speedup (see the Amdahl's-law discussion in the report).
 */
#define PAR_CUTOFF 50000

static void quickSortParallel(int arr[], int low, int high, int depth)
{
    if (low >= high)
        return;

    if (depth <= 0 || (high - low) < PAR_CUTOFF) {
        quickSort(arr, low, high);
        return;
    }

    {
        int pi = partition(arr, low, high);

#pragma omp task shared(arr) firstprivate(low, pi, depth)
        quickSortParallel(arr, low, pi - 1, depth - 1);

#pragma omp task shared(arr) firstprivate(high, pi, depth)
        quickSortParallel(arr, pi + 1, high, depth - 1);

#pragma omp taskwait
    }
}

static void quickSortOMP(int arr[], int n)
{
    int depth = 0;
    int t = omp_get_max_threads();

    while ((1 << depth) < t)
        depth++;
    depth += 1; /* a little oversubscription helps load balance */

#pragma omp parallel
    {
#pragma omp single nowait
        quickSortParallel(arr, 0, n - 1, depth);
    }
}
#endif /* _OPENMP */

/* ------------------------------------------------------------------ */
/* Benchmark driver                                                    */
/* ------------------------------------------------------------------ */

enum algo { ALGO_BUBBLE, ALGO_QUICK, ALGO_OMP };

struct result {
    const char *name;
    double cpu;
    double wall;
    int ok;
    unsigned long long cmp;
    unsigned long long swaps;
};

/*
 * Dispatch through a switch rather than a function pointer.
 *
 * An earlier version used small `bubble_adapter`/`quick_adapter` wrappers so
 * both sorts shared one function-pointer signature. That was a mistake for a
 * profiling lab: at -O2/-O3 the wrappers survive as separate symbols and the
 * sort gets inlined *into* them, so gprof reported the hotspot as
 * "bubble_adapter" - an artefact of the harness, not of the algorithm.
 * A switch inlines away cleanly and leaves bubbleSort/quickSort as the names
 * that show up in the profile.
 */
static void dispatch(enum algo a, int *work, int n)
{
    switch (a) {
    case ALGO_BUBBLE:
        bubbleSort(work, n);
        break;
    case ALGO_QUICK:
        quickSort(work, 0, n - 1);
        break;
    case ALGO_OMP:
#ifdef _OPENMP
        quickSortOMP(work, n);
#endif
        break;
    }
}

/*
 * Time one algorithm.
 *
 * Reported time is the BEST of `repeat` runs. Best-of is the right summary for
 * a benchmark: noise from scheduling, interrupts and frequency scaling can only
 * ever make a run slower, never faster, so the minimum is the closest estimate
 * of the true cost.
 *
 * Wall time comes from CLOCK_MONOTONIC and is the primary metric. CPU time from
 * clock() is kept for reference, but see README section 5: in the -pg builds on
 * this kernel clock() under-reports sub-millisecond intervals, reading 0.0000 s
 * for a quicksort that CLOCK_MONOTONIC and getrusage both put at ~1-3 ms.
 */
static void run_one(struct result *r, const char *name, enum algo a,
                    const int *master, int *work, int n, int repeat)
{
    int k;

    r->name = name;
    r->cpu = -1.0;
    r->wall = -1.0;
    r->ok = 1;

    for (k = 0; k < repeat; k++) {
        double c0, w0, c1, w1;

        /* Restore the same unsorted input before every timed run - otherwise
         * run 2 onwards would be sorting already-sorted data. */
        memcpy(work, master, (size_t)n * sizeof(int));

#ifdef COUNTERS
        g_cmp = 0;
        g_swap = 0;
#endif

        c0 = cpu_seconds();
        w0 = wall_seconds();

        dispatch(a, work, n);

        w1 = wall_seconds();
        c1 = cpu_seconds();

        if (r->wall < 0.0 || (w1 - w0) < r->wall) {
            r->wall = w1 - w0;
            r->cpu = c1 - c0;
        }
        if (!is_sorted(work, n))
            r->ok = 0;
    }

#ifdef COUNTERS
    r->cmp = g_cmp;
    r->swaps = g_swap;
#else
    r->cmp = 0;
    r->swaps = 0;
#endif
}

static void usage(const char *prog)
{
    fprintf(stderr,
            "Usage: %s [N] [--quick-only] [--bubble-only] [--parallel] [--csv]\n"
            "          [--seed S] [--repeat R]\n",
            prog);
}

int main(int argc, char **argv)
{
    int n = DEFAULT_N;
    int do_bubble = 1, do_quick = 1, do_par = 0, csv = 0, repeat = 1;
    unsigned int seed = 12345u;
    int *master = NULL, *work = NULL;
    struct result res[3];
    int nres = 0, i;

    for (i = 1; i < argc; i++) {
        if (argv[i][0] != '-') {
            n = atoi(argv[i]);
        } else if (!strcmp(argv[i], "--quick-only")) {
            do_bubble = 0;
        } else if (!strcmp(argv[i], "--bubble-only")) {
            do_quick = 0;
        } else if (!strcmp(argv[i], "--parallel")) {
            do_par = 1;
        } else if (!strcmp(argv[i], "--csv")) {
            csv = 1;
        } else if (!strcmp(argv[i], "--seed") && i + 1 < argc) {
            seed = (unsigned int)strtoul(argv[++i], NULL, 10);
        } else if (!strcmp(argv[i], "--repeat") && i + 1 < argc) {
            repeat = atoi(argv[++i]);
            if (repeat < 1)
                repeat = 1;
        } else {
            usage(argv[0]);
            return 1;
        }
    }

    if (n < 2) {
        fprintf(stderr, "N must be >= 2\n");
        return 1;
    }

    master = (int *)malloc((size_t)n * sizeof(int));
    work = (int *)malloc((size_t)n * sizeof(int));
    if (!master || !work) {
        printf("Memory allocation failed\n");
        free(master);
        free(work);
        return 1;
    }

    generate_temperatures(master, n, seed);

    if (!csv) {
        printf("=====================================================\n");
        printf(" Weather Analytics - Sorting Benchmark\n");
        printf("=====================================================\n");
        printf(" Records        : %d daily temperature readings\n", n);
        printf(" Equivalent to  : %.1f years of daily data\n", n / 365.0);
        printf(" Storage        : int, millidegrees Celsius\n");
        printf(" Sample [0..4]  : %.3f %.3f %.3f %.3f %.3f C\n",
               master[0] / 1000.0, master[1 % n] / 1000.0, master[2 % n] / 1000.0,
               master[3 % n] / 1000.0, master[4 % n] / 1000.0);
        printf(" RNG seed       : %u (reproducible)\n", seed);
        printf("-----------------------------------------------------\n");
    }

    if (do_bubble)
        run_one(&res[nres++], "Bubble Sort", ALGO_BUBBLE, master, work, n, repeat);
    if (do_quick)
        run_one(&res[nres++], "Quick Sort", ALGO_QUICK, master, work, n, repeat);
    if (do_par) {
#ifdef _OPENMP
        run_one(&res[nres++], "Quick Sort (OpenMP)", ALGO_OMP, master, work, n, repeat);
#else
        fprintf(stderr, "warning: --parallel ignored (rebuild with -fopenmp)\n");
#endif
    }

    if (csv) {
        /* n,algorithm,cpu_seconds,wall_seconds,sorted,comparisons,swaps */
        for (i = 0; i < nres; i++)
            printf("%d,%s,%.6f,%.6f,%d,%llu,%llu\n", n, res[i].name, res[i].cpu,
                   res[i].wall, res[i].ok, res[i].cmp, res[i].swaps);
    } else {
        printf(" %-22s %12s %12s %8s\n", "Algorithm", "CPU (s)", "Wall (s)", "Sorted");
        for (i = 0; i < nres; i++)
            printf(" %-22s %12.4f %12.4f %8s\n", res[i].name, res[i].cpu, res[i].wall,
                   res[i].ok ? "yes" : "NO");
#ifdef COUNTERS
        printf("-----------------------------------------------------\n");
        printf(" %-22s %18s %18s\n", "Algorithm", "Comparisons", "Swaps");
        for (i = 0; i < nres; i++)
            printf(" %-22s %18llu %18llu\n", res[i].name, res[i].cmp, res[i].swaps);
#endif
        printf("-----------------------------------------------------\n");

        /* Wall time, not CPU time: for the OpenMP run CPU time sums across all
         * threads, so a CPU-time ratio would report a *slowdown* for a sort
         * that actually finished sooner. */
        for (i = 1; i < nres; i++)
            if (res[i].wall > 0.0)
                printf(" Speedup (%s / %s): %.1fx  [wall clock]\n", res[0].name,
                       res[i].name, res[0].wall / res[i].wall);
        printf("=====================================================\n");
    }

    free(master);
    free(work);
    return 0;
}
