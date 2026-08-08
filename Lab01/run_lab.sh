#!/usr/bin/env bash
#
# run_lab.sh - reproduce every measurement in this lab from a clean checkout.
#
#   ./run_lab.sh          # full pipeline except the ~10 min bubble-sort-at-1M run
#   ./run_lab.sh --with-1m  # also run bubble sort on 1,000,000 elements
#
# Produces: myreport.txt report_O2.txt report_O3.txt time_*.txt
#           perf_*.txt scaling.csv counters.txt
set -u

cd "$(dirname "$0")"
WITH_1M=0
[ "${1:-}" = "--with-1m" ] && WITH_1M=1

hr() { printf '=%.0s' {1..70}; echo; }
say() { hr; echo "  $*"; hr; }

# ---------------------------------------------------------------- 0. toolchain
say "0. Toolchain versions"
{
  gcc --version | head -1
  gprof --version | head -1
  (perf --version 2>&1 | head -1) || echo "perf: NOT INSTALLED"
  echo "kernel: $(uname -r)"
  echo "cpu:    $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')"
} | tee toolchain.txt

# ---------------------------------------------------------------- 1. build
say "1. Building (exact command lines from the lab sheet)"
set -e
gcc -O0 -pg mysort.c -o mysort
gcc -O2 -pg mysort.c -o mysort_O2
gcc -O3 -pg mysort.c -o mysort_O3
# extra builds: no -pg (clean timing) and instrumented (operation counts)
gcc -O2 mysort.c -o mysort_bench
gcc -O0 mysort.c -o mysort_bench_O0
gcc -O2 -DCOUNTERS mysort.c -o mysort_counters
gcc -O2 -fopenmp mysort.c -o mysort_omp
set +e
echo "built: mysort mysort_O2 mysort_O3 mysort_bench mysort_counters mysort_omp"

# ------------------------------------------------- 2. run + time + gprof each
profile_level () {          # $1 = binary   $2 = gprof output   $3 = label
  local bin="$1" out="$2" label="$3"
  say "Profiling $label  ($bin)"
  ./"$bin" | tee "run_${label}.txt"
  echo
  echo "--- time ./$bin (3 runs) ---" | tee "time_${label}.txt"
  for i in 1 2 3; do
    { time ./"$bin" >/dev/null ; } 2>> "time_${label}.txt"
  done
  cat "time_${label}.txt"
  gprof "./$bin" gmon.out > "$out" 2>/dev/null
  echo ">>> wrote $out"
  echo "--- flat profile head ---"
  sed -n '1,12p' "$out"
}

profile_level mysort    myreport.txt  O0
profile_level mysort_O2 report_O2.txt O2
profile_level mysort_O3 report_O3.txt O3

# At N=18250 quicksort finishes in about 1 ms, but gprof's sampling period is
# 10 ms - so quicksort collects ZERO samples and its self-time prints as 0.00 s.
# To profile quicksort itself we need a run long enough to sample: 4,000,000
# records at -O0 takes seconds, which is hundreds of samples.
say "2b. Quicksort-only profile at N=4,000,000 (-O0, so gprof can sample it)"
./mysort 4000000 --quick-only | tee run_quick4M.txt
gprof ./mysort gmon.out > report_quick_4M.txt 2>/dev/null
echo ">>> wrote report_quick_4M.txt"
sed -n '1,12p' report_quick_4M.txt

# ---------------------------------------------------------------- 3. perf
say "3. Hardware performance counters (perf stat)"
if command -v perf >/dev/null 2>&1; then
  for b in mysort mysort_O2 mysort_O3; do
    echo "### perf stat ./$b"
    perf stat -e task-clock,context-switches,page-faults,cycles,instructions,\
cache-references,cache-misses,branch-instructions,branch-misses \
      ./"$b" 2>&1 | tee "perf_${b}.txt"
    echo
  done
else
  echo "perf is not installed on this machine."          | tee perf_UNAVAILABLE.txt
  echo "Kernel: $(uname -r)"                             | tee -a perf_UNAVAILABLE.txt
  echo "See README section 7 for the PMU availability probe and the substitute" \
                                                         | tee -a perf_UNAVAILABLE.txt
  echo "measurements used in its place."                 | tee -a perf_UNAVAILABLE.txt
fi

# Whether or not perf exists, record WHY hardware counters do or do not work.
say "3b. PMU availability probe (perf_event_open)"
gcc -O0 perf_probe.c -o perf_probe 2>/dev/null && {
  {
    echo "perf_event_open() hardware-counter availability probe"
    echo "kernel: $(uname -r)"
    echo "perf_event_paranoid: $(cat /proc/sys/kernel/perf_event_paranoid)"
    echo
    ./perf_probe
  } | tee perf_probe_output.txt
}

# Cachegrind SIMULATES the counters the PMU cannot provide: instruction counts,
# cache references/misses and branch mispredictions. It is a simulator, not the
# real hardware - the numbers are architecturally faithful but not cycle-exact.
say "3c. Cachegrind (substitute for the unavailable hardware counters)"
if command -v valgrind >/dev/null 2>&1; then
  # N kept small: cachegrind runs ~50x slower than native.
  for algo in bubble quick; do
    echo "### cachegrind, ${algo} sort, N=8000"
    valgrind --tool=cachegrind --branch-sim=yes --cache-sim=yes \
             --cachegrind-out-file=cachegrind_${algo}.out \
             ./mysort_bench 8000 --${algo}-only 2>&1 | tee cachegrind_${algo}.txt
    echo
  done
else
  echo "valgrind not installed - skipping (install: sudo apt install -y valgrind)" \
    | tee cachegrind_UNAVAILABLE.txt
fi

# ---------------------------------------------------------------- 4. counters
say "4. Operation counts (comparisons / swaps), -O2 -DCOUNTERS"
./mysort_counters | tee counters.txt

# ---------------------------------------------------------------- 5. scaling
say "5. Scaling study (-O2, no -pg)"
# Repeat counts are chosen so every row is a stable best-of measurement without
# the script taking all day: cheap sizes get more repeats, expensive ones fewer.
# These are the exact settings behind the tables in README section 9.
echo "n,algorithm,cpu_seconds,wall_seconds,sorted,comparisons,swaps" > scaling.csv

for n in 1000 2000 4000 8000 18250 32000; do
  echo "  bubble n=$n (best of 3)"
  ./mysort_bench "$n" --bubble-only --repeat 3 --csv >> scaling.csv
done
for n in 64000 128000 256000; do
  echo "  bubble n=$n (single run - already seconds long)"
  ./mysort_bench "$n" --bubble-only --repeat 1 --csv >> scaling.csv
done

if [ "$WITH_1M" = "1" ]; then
  echo "  bubble n=1000000  (~15 minutes)"
  ./mysort_bench 1000000 --bubble-only --repeat 1 --csv >> scaling.csv
elif [ -f bubble_1M.csv ]; then
  echo "  bubble n=1000000  (reusing saved bubble_1M.csv; --with-1m to re-measure)"
  cat bubble_1M.csv >> scaling.csv
fi

for n in 1000 2000 4000 8000 18250 32000 64000 128000 256000 \
         500000 1000000 2000000 4000000 8000000; do
  echo "  quick  n=$n (best of 5)"
  ./mysort_bench "$n" --quick-only --repeat 5 --csv >> scaling.csv
done
column -s, -t scaling.csv

# --------------------------------------------------- 5b. optimization sweep
say "5b. Optimization-level sweep (best of 9, no -pg)"
for o in O0 O1 O2 O3; do gcc -$o mysort.c -o "/tmp/sweep_$o"; done
echo "opt,algorithm,wall_seconds" > opt_sweep.csv
printf "%-6s %16s %14s\n" "opt" "bubble(18250)" "quick(1M)"
for o in O0 O1 O2 O3; do
  b=$("/tmp/sweep_$o" 18250   --bubble-only --repeat 9 --csv | cut -d, -f4)
  q=$("/tmp/sweep_$o" 1000000 --quick-only  --repeat 9 --csv | cut -d, -f4)
  printf "%-6s %16s %14s\n" "-$o" "$b" "$q"
  printf -- "-%s,Bubble Sort,%s\n-%s,Quick Sort,%s\n" "$o" "$b" "$o" "$q" >> opt_sweep.csv
done
rm -f /tmp/sweep_O0 /tmp/sweep_O1 /tmp/sweep_O2 /tmp/sweep_O3

# ---------------------------------------------------------------- 6. parallel
say "6. Parallel quicksort feasibility (OpenMP)"
./mysort_omp 4000000 --quick-only --parallel | tee parallel.txt

say "DONE"
