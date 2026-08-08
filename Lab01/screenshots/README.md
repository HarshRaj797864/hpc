# Screenshots

Capture these yourself — a screenshot is evidence that *you* ran the tool on
*your* machine, so generating them automatically would defeat the purpose.

## Run this first — in the same terminal you take the screenshots from

`$PERF` only exists in the shell where you export it. If you open a new tab, or
skip straight to a table row below, `$PERF --version` becomes bare `--version`
and bash reports `command not found`. Re-run this block if that happens.

On WSL2 the plain `perf` wrapper cannot find a binary matching the running
kernel, so we locate the versioned one instead:

```bash
export PERF=$(ls /usr/lib/linux-tools-*/perf | head -1)
echo "$PERF"          # should print a path, not an empty line

gcc -O0 -pg mysort.c -o mysort
gcc -O2 -pg mysort.c -o mysort_O2
gcc -O3 -pg mysort.c -o mysort_O3
gcc -O2 mysort.c -o mysort_bench
gcc -O2 -DCOUNTERS mysort.c -o mysort_counters
gcc -O2 -fopenmp mysort.c -o mysort_omp
```

The lab sheet asks only for a `screenshots/` folder — it does **not** specify a
count. The list below is split accordingly.

## Core set — the lab's own "Record the following" steps

Capture these eleven and every explicit instruction in the brief is evidenced.

| # | Filename | Command | Covers which lab step |
|---|---|---|---|
| 1 | `01_versions.png` | `gcc --version && gprof --version && $PERF --version` | Software Requirements |
| 2 | `02_compile.png` | `gcc -O0 -pg mysort.c -o mysort` | Compile the Program |
| 3 | `03_run_O0.png` | `./mysort` | Execute the Program |
| 4 | `04_time_O0.png` | `time ./mysort` | Record Real / User / Sys time |
| 5 | `05_gprof_flat_O0.png` | `gprof ./mysort gmon.out > myreport.txt && head -20 myreport.txt` | Max-CPU function, % CPU, call counts |
| 6 | `06_gprof_callgraph_O0.png` | `sed -n '/Call graph/,/^Index/p' myreport.txt \| head -45` | Call Graph |
| 7 | `07_perf_stat_O0.png` | `$PERF stat -e task-clock,context-switches,page-faults,cycles,instructions,cache-references,cache-misses,branch-instructions,branch-misses ./mysort` | Hardware statistics |
| 8 | `08_gprof_O2.png` | `./mysort_O2 && gprof ./mysort_O2 gmon.out > report_O2.txt && head -12 report_O2.txt` | -O2 report |
| 9 | `09_perf_stat_O2.png` | `$PERF stat ./mysort_O2` | -O2 hardware statistics |
| 10 | `10_gprof_O3.png` | `./mysort_O3 && gprof ./mysort_O3 gmon.out > report_O3.txt && head -12 report_O3.txt` | -O3 report |
| 11 | `11_perf_stat_O3.png` | `$PERF stat ./mysort_O3` | -O3 hardware statistics |

## Supporting set — optional

These back up analysis that goes beyond the brief. Skip any of them and the
deliverable is still complete; #12 and #14 are the two most worth having,
since they evidence the report's headline claims.

| # | Filename | Command | Supports |
|---|---|---|---|
| 12 | `12_cachegrind.png` | `valgrind --tool=cachegrind --branch-sim=yes --cache-sim=yes ./mysort_bench 18250 --bubble-only` | §7.2–7.3, the counters the PMU cannot give |
| 13 | `13_counters.png` | `./mysort_counters` | §6.3 comparison/swap counts |
| 14 | `14_bubble_1M.png` | `./mysort_bench 1000000 --bubble-only` (~15 min) | §9, the 871.8 s headline |
| 15 | `15_quick_1M.png` | `./mysort_bench 1000000 --quick-only --repeat 5` | §9, the 0.070 s counterpart |
| 16 | `16_gprof_quick_4M.png` | `./mysort 4000000 --quick-only && gprof ./mysort gmon.out \| head -12` | §6.4, quicksort's own hotspot |
| 17 | `17_parallel.png` | `./mysort_omp 4000000 --quick-only --parallel` | §10, parallel feasibility |

## Note on the perf screenshots (7, 9, 11)

`perf stat` on this machine reports `<not supported>` for every hardware counter
(cycles, instructions, cache references/misses, branch misses), because the WSL2
kernel exposes no virtual PMU. **That output is itself the result** — capture it
as-is. Screenshot 11 shows the underlying cause at the syscall level. See
README §7.

To capture real hardware counters, run these on native, non-virtualised Linux.

## Note on screenshots 14 and 15

These are the headline comparison: bubble sort takes **871.8 s** on 1,000,000
records, quicksort **0.070 s** on the same array.
