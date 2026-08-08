# Screenshots

Terminal captures evidencing each step of the lab. The lab sheet asks only for
a `screenshots/` folder and specifies no count; the **core set** below covers
every explicit "Record the following" instruction in the brief, and the
**optional set** supports the extra analysis in `../README.md`.

**Run every command from `Lab01/`, not from this folder** — the reports and
binaries live one level up.

## Setup — run this first, in the same terminal

`$PERF` only exists in the shell where you export it. Open a new tab and it is
gone, and `$PERF stat ...` silently becomes `stat ...`.

```bash
cd ~/programming-playground/repos/hpc/Lab01

export PERF=$(ls /usr/lib/linux-tools-*/perf | head -1)
echo "$PERF"          # must print a path, not an empty line

gcc -O0 -pg mysort.c -o mysort
gcc -O2 -pg mysort.c -o mysort_O2
gcc -O3 -pg mysort.c -o mysort_O3
gcc -O2 mysort.c -o mysort_bench
gcc -O2 -DCOUNTERS mysort.c -o mysort_counters
gcc -O2 -fopenmp mysort.c -o mysort_omp
```

---

## Core set

### 01_versions.png — Software Requirements
```bash
gcc --version && gprof --version && $PERF --version
```

### 02_run_O0.png — Compile and Execute
```bash
gcc -O0 -pg mysort.c -o mysort && ./mysort
```

### 03_time_O0.png — Record Real / User / Sys time
```bash
time ./mysort
```

### 04_gprof_flat_O0.png — Max-CPU function, % CPU, call counts
```bash
gprof ./mysort gmon.out > myreport.txt && head -20 myreport.txt
```

### 05_perf_stat_O0.png — Hardware statistics
```bash
$PERF stat -e task-clock,context-switches,page-faults,cycles,instructions,cache-references,cache-misses,branch-instructions,branch-misses ./mysort
```

### 06_gprof_O2.png — -O2 profile
```bash
./mysort_O2 && gprof ./mysort_O2 gmon.out > report_O2.txt && head -12 report_O2.txt
```

### 07_perf_stat_O2.png — -O2 hardware statistics
```bash
$PERF stat ./mysort_O2
```

### 08_gprof_O3.png — -O3 profile
```bash
./mysort_O3 && gprof ./mysort_O3 gmon.out > report_O3.txt && head -12 report_O3.txt
```

### 09_perf_stat_O3.png — -O3 hardware statistics
```bash
$PERF stat ./mysort_O3
```

### 10_gprof_callgraph_O0.png — Call Graph
The brief lists "Call Graph" explicitly under *Record the following*.
```bash
sed -n '/Call graph/,/^Index/p' myreport.txt | head -45
```

---

## Optional set

Supporting evidence for analysis beyond the brief. Skipping these leaves the
deliverable complete.

### 11_cachegrind.png — §7.2–7.3, the counters the PMU cannot provide
```bash
valgrind --tool=cachegrind --branch-sim=yes --cache-sim=yes ./mysort_bench 18250 --bubble-only
```

### 12_counters.png — §6.3, exact comparison and swap counts
```bash
./mysort_counters
```

### 13_bubble_1M.png — §9, the 871.8 s headline (takes ~15 minutes)
```bash
./mysort_bench 1000000 --bubble-only
```

### 14_quick_1M.png — §9, the 0.070 s counterpart
```bash
./mysort_bench 1000000 --quick-only --repeat 5
```

### 15_gprof_quick_4M.png — §6.4, quicksort's own hotspot
```bash
./mysort 4000000 --quick-only && gprof ./mysort gmon.out | head -12
```

### 16_parallel.png — §10, parallel feasibility
```bash
./mysort_omp 4000000 --quick-only --parallel
```

---

## Note on the perf screenshots (05, 07, 09)

`perf stat` reports `<not supported>` for every hardware counter — cycles,
instructions, cache references/misses, branch misses — because this WSL2 kernel
exposes no virtual PMU. **That output is itself the result**; capture it as-is.
See `../README.md` §7.1 for the `perf_event_open` evidence, and §7.2 for the
Cachegrind measurements that fill the gap.

Real hardware counters require native, non-virtualised Linux.

## Note on gprof percentages

The `% time` column is sampled and shifts a few points between runs; the
`calls` column is exact instrumentation and does not. If a screenshot shows
`bubbleSort` at a slightly different percentage from `../README.md`, that is
expected and explained in §6.1.
