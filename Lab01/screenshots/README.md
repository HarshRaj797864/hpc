# Screenshots

Capture these yourself — a screenshot is evidence that *you* ran the tool on
*your* machine, so generating them automatically would defeat the purpose.

Build first:

```bash
gcc -O0 -pg mysort.c -o mysort
gcc -O2 -pg mysort.c -o mysort_O2
gcc -O3 -pg mysort.c -o mysort_O3
gcc -O2 mysort.c -o mysort_bench
gcc -O2 -DCOUNTERS mysort.c -o mysort_counters
gcc -O2 -fopenmp mysort.c -o mysort_omp
```

| # | Filename | Command to run and capture |
|---|---|---|
| 1 | `01_versions.png` | `gcc --version && gprof --version && perf --version` |
| 2 | `02_compile.png` | `gcc -O0 -pg mysort.c -o mysort` |
| 3 | `03_run_O0.png` | `./mysort` |
| 4 | `04_time_O0.png` | `time ./mysort` |
| 5 | `05_gprof_flat_O0.png` | `gprof ./mysort gmon.out > myreport.txt && head -20 myreport.txt` |
| 6 | `06_gprof_callgraph_O0.png` | `sed -n '/Call graph/,/^Index/p' myreport.txt \| head -45` |
| 7 | `07_gprof_O2.png` | `./mysort_O2 && gprof ./mysort_O2 gmon.out > report_O2.txt && head -12 report_O2.txt` |
| 8 | `08_gprof_O3.png` | `./mysort_O3 && gprof ./mysort_O3 gmon.out > report_O3.txt && head -12 report_O3.txt` |
| 9 | `09_gprof_quick_4M.png` | `./mysort 4000000 --quick-only && gprof ./mysort gmon.out \| head -12` |
| 10 | `10_perf_stat.png` | `perf stat ./mysort` |
| 11 | `11_pmu_probe.png` | `./perf_probe` (source is in README §7.1) |
| 12 | `12_counters.png` | `./mysort_counters` |
| 13 | `13_bubble_1M.png` | `./mysort_bench 1000000 --bubble-only` (~15 minutes) |
| 14 | `14_quick_1M.png` | `./mysort_bench 1000000 --quick-only --repeat 5` |
| 15 | `15_parallel.png` | `./mysort_omp 4000000 --quick-only --parallel` |

## Note on screenshot 10

`perf stat` on this machine reports `<not supported>` for every hardware counter
(cycles, instructions, cache references/misses, branch misses), because the WSL2
kernel exposes no virtual PMU. **That output is itself the result** — capture it
as-is. Screenshot 11 shows the underlying cause at the syscall level. See
README §7.

To capture real hardware counters, run screenshot 10 on native,
non-virtualised Linux.

## Note on screenshots 13 and 14

These are the headline comparison: bubble sort takes **871.8 s** on 1,000,000
records, quicksort **0.070 s** on the same array.
