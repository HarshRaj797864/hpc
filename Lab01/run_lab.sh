#!/usr/bin/env bash
# =============================================================================
# run_lab.sh — Reproduce ALL Lab01 experiments
#
# This script is the single source of truth for every experiment in README.md.
# It runs inside the Docker container (or directly on the host) and writes
# all result files to ./results/.
#
# Usage (inside container):
#   bash run_lab.sh [--skip-bubble-large]
#
#   --skip-bubble-large  Skip bubble sort at N=1,000,000 (~15 min runtime).
#                        Use this if you only need quick results.
#
# Environment variables (override defaults):
#   PERF         path to the perf binary  (default: auto-detect)
#   SKIP_LARGE   set to 1 to skip N=1,000,000 bubble sort
# =============================================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()    { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
step()  { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}"; }
die()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ── Parse arguments ──────────────────────────────────────────────────────────
SKIP_LARGE=${SKIP_LARGE:-0}
for arg in "$@"; do
    case "$arg" in
        --skip-bubble-large) SKIP_LARGE=1 ;;
        *) warn "Unknown argument: $arg" ;;
    esac
done

# ── Detect perf ──────────────────────────────────────────────────────────────
if [ -z "${PERF:-}" ] || [ ! -x "${PERF}" ]; then
    PERF=$(ls /usr/lib/linux-tools-*/perf 2>/dev/null | head -1 || true)
    [ -z "$PERF" ] && PERF=$(which perf 2>/dev/null || true)
    [ -z "$PERF" ] && warn "perf not found — perf stat steps will be skipped"
fi
[ -n "$PERF" ] && info "Using perf: $PERF ($($PERF --version 2>&1 | head -1))"

# ── Setup ────────────────────────────────────────────────────────────────────
RESULTS="$(pwd)/results"
mkdir -p "$RESULTS"
SRC="mysort.c"
[ -f "$SRC" ] || die "mysort.c not found in $(pwd)"

# ── Section 3: Environment snapshot ──────────────────────────────────────────
step "§3 Environment"
{
    echo "=== Environment ==="
    echo "Date: $(date)"
    echo "Kernel: $(uname -r)"
    echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "Cores: $(nproc)"
    echo "GCC: $(gcc --version | head -1)"
    echo "gprof: $(gprof --version 2>&1 | head -1)"
    echo "valgrind: $(valgrind --version 2>&1 | head -1)"
    [ -n "${PERF}" ] && echo "perf: $($PERF --version 2>&1 | head -1)" || echo "perf: not available"
    echo ""
    echo "=== Memory ==="
    grep MemTotal /proc/meminfo
    echo ""
    echo "=== Cache topology ==="
    for f in /sys/devices/system/cpu/cpu0/cache/index*/size; do
        lvl=$(cat "$(dirname $f)/level")
        typ=$(cat "$(dirname $f)/type")
        sz=$(cat "$f")
        echo "  L${lvl} ${typ}: ${sz}"
    done 2>/dev/null || echo "  (cache info not available)"
} | tee "$RESULTS/environment.txt"
ok "environment.txt written"

# ── Section 2: Build everything ───────────────────────────────────────────────
step "§2 Build all binaries"

build() {
    local flags="$1" out="$2"
    info "gcc $flags mysort.c -o $out"
    gcc $flags mysort.c -o "$out"
}

build "-O0 -pg"                        mysort
build "-O2 -pg"                        mysort_O2
build "-O3 -pg"                        mysort_O3
build "-O0"                            mysort_bench_O0
build "-O2"                            mysort_bench
build "-O1"                            mysort_O1
build "-O3 -fno-tree-vectorize"        mysort_O3_novect
build "-O3 -fno-if-conversion"         mysort_O3_noifconv
build "-O2 -DCOUNTERS"                 mysort_counters
if gcc -O2 -fopenmp mysort.c -o mysort_omp 2>/dev/null; then
    ok "mysort_omp built (OpenMP available)"
    HAS_OMP=1
else
    warn "OpenMP not available — §10 will be skipped"
    HAS_OMP=0
fi
ok "All binaries built"

# ── Helper: timed run ─────────────────────────────────────────────────────────
run_timed() {
    # Usage: run_timed <output_file> <binary> [args...]
    local out="$1"; shift
    info "Running: $*"
    /usr/bin/time -v "$@" 2>&1 | tee "$RESULTS/$out"
}

# ── Section 5.1: time ./mysort (all three builds) ────────────────────────────
step "§5.1 time — all three builds at N=18250"
for bin in mysort mysort_O2 mysort_O3; do
    info "timing $bin"
    { time ./$bin; } 2>&1 | tee "$RESULTS/time_${bin}.txt"
done
ok "time results written"

# ── Section 5.2: in-program timing ───────────────────────────────────────────
step "§5.2 In-program timing (N=18250, best of 3)"
./mysort_bench --repeat 3 | tee "$RESULTS/timing_O2_bench.txt"
./mysort_bench_O0 --repeat 3 | tee "$RESULTS/timing_O0_bench.txt"
ok "in-program timing written"

# ── Section 6: gprof ─────────────────────────────────────────────────────────
step "§6 gprof profiles"

# O0 — both sorts
info "gprof: O0 (bubble + quick)"
./mysort
gprof ./mysort gmon.out > "$RESULTS/myreport.txt"
cp "$RESULTS/myreport.txt" myreport.txt
ok "myreport.txt (O0)"

# O2
info "gprof: O2"
./mysort_O2
gprof ./mysort_O2 gmon.out > "$RESULTS/report_O2.txt"
cp "$RESULTS/report_O2.txt" report_O2.txt
ok "report_O2.txt"

# O3
info "gprof: O3"
./mysort_O3
gprof ./mysort_O3 gmon.out > "$RESULTS/report_O3.txt"
cp "$RESULTS/report_O3.txt" report_O3.txt
ok "report_O3.txt"

# §6.4 — quicksort-only profile at N=4,000,000
step "§6.4 gprof quicksort-only at N=4,000,000"
info "Running quicksort at N=4000000 for gprof sampling…"
./mysort 4000000 --quick-only
gprof ./mysort gmon.out > "$RESULTS/report_quick_4M.txt"
ok "report_quick_4M.txt"

# §6.3 — counters
step "§6.3 Exact comparison/swap counts (-DCOUNTERS)"
./mysort_counters | tee "$RESULTS/counters_output.txt"
ok "counters_output.txt"

# ── Section 7.1: perf stat ────────────────────────────────────────────────────
step "§7.1 perf stat"
if [ -n "${PERF}" ] && [ -x "${PERF}" ]; then
    for bin in mysort mysort_O2 mysort_O3; do
        info "perf stat: $bin (errors are non-fatal)"
        $PERF stat ./$bin 2>&1 | tee "$RESULTS/perf_stat_${bin}.txt" || true
    done

    # Extended perf stat — try hardware counters (needs --privileged on native Linux)
    info "perf stat: extended counters attempt on mysort"
    $PERF stat \
        -e task-clock,context-switches,page-faults,cycles,instructions,\
cache-references,cache-misses,branch-instructions,branch-misses \
        ./mysort 2>&1 | tee "$RESULTS/perf_stat_extended_O0.txt" || true
    ok "perf stat done (hardware counters show <not supported> on WSL2/containers)"
else
    warn "perf not available — skipping §7.1"
    echo "perf not available" > "$RESULTS/perf_stat_skipped.txt"
fi

# ── Section 7.2: Cachegrind ───────────────────────────────────────────────────
step "§7.2 Cachegrind (valgrind)"
info "Cachegrind: bubble sort N=18250"
valgrind --tool=cachegrind --branch-sim=yes --cache-sim=yes \
         --cachegrind-out-file="$RESULTS/cachegrind_bubble.out" \
         ./mysort_bench 18250 --bubble-only 2>&1 | tee "$RESULTS/cachegrind_bubble.txt"

info "Cachegrind: quick sort N=18250"
valgrind --tool=cachegrind --branch-sim=yes --cache-sim=yes \
         --cachegrind-out-file="$RESULTS/cachegrind_quick.out" \
         ./mysort_bench 18250 --quick-only 2>&1 | tee "$RESULTS/cachegrind_quick.txt"
ok "Cachegrind results written"

# ── Section 8: Compiler optimization comparison ───────────────────────────────
# Wall time is the 4th field for "Bubble Sort" (3 words + cpu + wall + sorted)
# and 3rd field for "Quick Sort" (2 words + cpu + wall + sorted).
# Use --csv mode to make parsing unambiguous.
step "§8 Compiler optimization comparison (N=18250 bubble, N=1,000,000 quick)"
{
    echo "=== §8 Detailed bubble sort timing at N=18250 (best of 5) ==="
    for bin in mysort_bench_O0 mysort_O1 mysort_bench mysort_O3_novect mysort_O3_noifconv; do
        echo ""
        echo "--- $bin (N=18250, bubble only, best of 5) ---"
        ./$bin 18250 --bubble-only --repeat 5 2>&1 || true
    done
    echo ""
    echo "=== Detailed quick sort timing at N=1,000,000 (best of 5) ==="
    for bin in mysort_bench_O0 mysort_O1 mysort_bench; do
        echo ""
        echo "--- $bin (N=1,000,000, quick only, best of 5) ---"
        ./$bin 1000000 --quick-only --repeat 5 2>&1 || true
    done
    echo ""
    echo "=== CSV summary (n,algo,cpu_s,wall_s,sorted,cmp,swaps) ==="
    for bin in mysort_bench_O0 mysort_O1 mysort_bench mysort_O3_novect mysort_O3_noifconv; do
        ./$bin 18250 --bubble-only --repeat 5 --csv 2>/dev/null | sed "s|^|${bin},|" || true
        ./$bin 18250 --quick-only  --repeat 5 --csv 2>/dev/null | sed "s|^|${bin},|" || true
    done
} | tee "$RESULTS/compiler_comparison_detailed.txt"
ok "Compiler comparison written"

# ── Section 8.2: O3 regression isolation ──────────────────────────────────────
step "§8.2 O3 regression: -fno-tree-vectorize vs -fno-if-conversion (best of 5)"
{
    echo "=== §8.2 O3 vectorizer regression isolation ==="
    for bin in mysort_bench mysort_O3_novect mysort_O3_noifconv; do
        label="$bin"
        echo ""
        echo "--- $label (N=18250, bubble only, best of 5) ---"
        ./$bin 18250 --bubble-only --repeat 5 2>&1
    done
} | tee "$RESULTS/o3_regression.txt"
ok "O3 regression results written"

# ── Section 9: Scaling table ──────────────────────────────────────────────────
step "§9 Scaling table — wall-clock seconds at various N"
{
    echo "=== §9 Effect of problem size ==="
    printf "%-12s %-15s %-15s\n" "N" "Bubble (s)" "Quick (s)"
    echo "─────────────────────────────────────────"

    # Use --csv for unambiguous parsing: n,algo,cpu_s,wall_s,sorted,cmp,swaps
    SIZES="1000 2000 4000 8000 18250 32000 64000 128000 256000"
    for N in $SIZES; do
        bubble=$(./mysort_bench $N --bubble-only --repeat 3 --csv 2>/dev/null | awk -F, '{print $4}' || echo "N/A")
        quick=$(./mysort_bench $N --quick-only  --repeat 3 --csv 2>/dev/null | awk -F, '{print $4}' || echo "N/A")
        printf "%-12s %-15s %-15s\n" "$N" "$bubble" "$quick"
    done

    # Large quick-only sizes (bubble is too slow)
    for N in 500000 1000000 2000000 4000000 8000000; do
        quick=$(./mysort_bench $N --quick-only --repeat 3 --csv 2>/dev/null | awk -F, '{print $4}' || echo "N/A")
        printf "%-12s %-15s %-15s\n" "$N" "(skipped)" "$quick"
    done

    if [ "$SKIP_LARGE" = "0" ]; then
        echo ""
        echo "Running bubble sort at N=1,000,000 (this takes ~15 minutes)..."
        bubble_1M=$(./mysort_bench 1000000 --bubble-only --csv 2>/dev/null | awk -F, '{print $4}' || echo "N/A")
        quick_1M=$(./mysort_bench 1000000 --quick-only --repeat 5 --csv 2>/dev/null | awk -F, '{print $4}' || echo "N/A")
        printf "%-12s %-15s %-15s\n" "1000000" "$bubble_1M" "$quick_1M"
    else
        warn "Skipping bubble sort at N=1,000,000 (--skip-bubble-large was set)"
        echo "N=1,000,000 bubble sort: SKIPPED (use SKIP_LARGE=0 or omit --skip-bubble-large)"
    fi
} | tee "$RESULTS/scaling_table.txt"
ok "Scaling table written"

# ── Section 10: OpenMP parallel quicksort ────────────────────────────────────
step "§10 OpenMP parallel quicksort (N=4,000,000)"
if [ "$HAS_OMP" = "1" ]; then
    {
        echo "=== §10 OpenMP parallel quicksort at N=4,000,000 ==="
        echo ""
        echo "--- Serial quicksort ---"
        ./mysort_bench 4000000 --quick-only --repeat 3 2>&1
        echo ""
        echo "--- OpenMP quicksort ---"
        ./mysort_omp 4000000 --quick-only --parallel --repeat 3 2>&1
    } | tee "$RESULTS/openmp_results.txt"
    ok "OpenMP results written"
else
    warn "OpenMP not available — §10 skipped"
    echo "OpenMP not available — rebuild with -fopenmp" > "$RESULTS/openmp_results.txt"
fi

# ── Perf probe (PMU availability check) ──────────────────────────────────────
step "PMU availability probe"
cat > /tmp/perf_probe.c << 'EOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <linux/perf_event.h>

static void try1(const char *name, unsigned type, unsigned long long cfg)
{
    struct perf_event_attr a;
    int fd;
    memset(&a, 0, sizeof a);
    a.size = sizeof a; a.type = type; a.config = cfg;
    a.disabled = 1; a.exclude_kernel = 1; a.exclude_hv = 1;
    fd = syscall(__NR_perf_event_open, &a, 0, -1, -1, 0);
    printf("%-22s : %s\n", name, fd < 0 ? strerror(errno) : "OK");
    if (fd >= 0) close(fd);
}

int main(void)
{
    try1("HW cpu-cycles",    PERF_TYPE_HARDWARE, PERF_COUNT_HW_CPU_CYCLES);
    try1("HW instructions",  PERF_TYPE_HARDWARE, PERF_COUNT_HW_INSTRUCTIONS);
    try1("HW cache-refs",    PERF_TYPE_HARDWARE, PERF_COUNT_HW_CACHE_REFERENCES);
    try1("HW branch-misses", PERF_TYPE_HARDWARE, PERF_COUNT_HW_BRANCH_MISSES);
    try1("SW task-clock",    PERF_TYPE_SOFTWARE, PERF_COUNT_SW_TASK_CLOCK);
    try1("SW page-faults",   PERF_TYPE_SOFTWARE, PERF_COUNT_SW_PAGE_FAULTS);
    return 0;
}
EOF
gcc -O0 /tmp/perf_probe.c -o /tmp/perf_probe 2>/dev/null && \
    /tmp/perf_probe | tee "$RESULTS/pmu_probe.txt" || \
    echo "perf_probe build failed" > "$RESULTS/pmu_probe.txt"
ok "PMU probe written"

# ── Summary ───────────────────────────────────────────────────────────────────
step "Done — results written to $RESULTS/"
echo ""
echo "Files:"
ls -lh "$RESULTS/"
echo ""
echo -e "${GREEN}${BOLD}All experiments complete.${RESET}"
echo "Copy results to host: they are in ./results/ (bind-mounted)"
