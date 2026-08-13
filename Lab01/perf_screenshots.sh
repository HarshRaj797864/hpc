#!/usr/bin/env bash
# =============================================================================
# perf_screenshots.sh — Run this in the Codespace terminal, then screenshot
#
# This script produces clean, well-labelled terminal output for each result
# that needs a screenshot. Each section is separated by a clear header so
# you can scroll to each one and take a screenshot.
#
# Usage (from Lab01/):
#   bash perf_screenshots.sh
#
# Or run individual sections:
#   bash perf_screenshots.sh versions
#   bash perf_screenshots.sh perf_O0
#   bash perf_screenshots.sh perf_O2
#   bash perf_screenshots.sh perf_O3
#   bash perf_screenshots.sh cachegrind_bubble
#   bash perf_screenshots.sh cachegrind_quick
#   bash perf_screenshots.sh gprof_4M
#   bash perf_screenshots.sh scaling
#   bash perf_screenshots.sh openmp
# =============================================================================

set -euo pipefail

# ── Resolve perf binary ───────────────────────────────────────────────────────
PERF=${PERF:-$(ls /usr/lib/linux-tools-*/perf 2>/dev/null | head -1 || which perf 2>/dev/null || echo "")}
[ -z "$PERF" ] && echo "ERROR: perf not found" && exit 1

# ── Build all binaries (idempotent) ──────────────────────────────────────────
build_all() {
    echo "Building binaries..."
    gcc -O0 -pg  mysort.c -o mysort
    gcc -O2 -pg  mysort.c -o mysort_O2
    gcc -O3 -pg  mysort.c -o mysort_O3
    gcc -O2      mysort.c -o mysort_bench
    gcc -O2 -fopenmp mysort.c -o mysort_omp 2>/dev/null && echo "  [OMP OK]" || echo "  [OMP skip]"
    echo "Done."
}

# ── Section printer ───────────────────────────────────────────────────────────
banner() {
    local title="$1"
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    printf  "║  %-60s║\n" "$title"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
section_versions() {
    banner "SCREENSHOT: Tool Versions"
    gcc --version
    echo ""
    valgrind --version
    echo ""
    $PERF --version
    echo ""
    echo "Kernel: $(uname -r)"
    echo "CPU:    $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo ""
    echo "PMU probe:"
    /tmp/perf_probe 2>/dev/null || gcc -O0 /tmp/perf_probe.c -o /tmp/perf_probe 2>/dev/null && /tmp/perf_probe
}

# ═══════════════════════════════════════════════════════════════════════════════
section_perf_O0() {
    banner "SCREENSHOT: perf stat -O0 (with hardware counters)"
    $PERF stat \
        -e task-clock,context-switches,page-faults,cycles,instructions,\
cache-references,cache-misses,branch-instructions,branch-misses \
        ./mysort 2>&1
}

section_perf_O2() {
    banner "SCREENSHOT: perf stat -O2 (with hardware counters)"
    $PERF stat \
        -e task-clock,context-switches,page-faults,cycles,instructions,\
cache-references,cache-misses,branch-instructions,branch-misses \
        ./mysort_O2 2>&1
}

section_perf_O3() {
    banner "SCREENSHOT: perf stat -O3 (with hardware counters)"
    $PERF stat \
        -e task-clock,context-switches,page-faults,cycles,instructions,\
cache-references,cache-misses,branch-instructions,branch-misses \
        ./mysort_O3 2>&1
}

# ═══════════════════════════════════════════════════════════════════════════════
section_cachegrind_bubble() {
    banner "SCREENSHOT: Cachegrind — Bubble Sort (N=18250)"
    valgrind --tool=cachegrind --branch-sim=yes --cache-sim=yes \
             ./mysort_bench 18250 --bubble-only 2>&1
}

section_cachegrind_quick() {
    banner "SCREENSHOT: Cachegrind — Quick Sort (N=18250)"
    valgrind --tool=cachegrind --branch-sim=yes --cache-sim=yes \
             ./mysort_bench 18250 --quick-only 2>&1
}

# ═══════════════════════════════════════════════════════════════════════════════
section_gprof_4M() {
    banner "SCREENSHOT: gprof — Quick Sort only at N=4,000,000"
    ./mysort 4000000 --quick-only
    gprof ./mysort gmon.out | head -20
}

# ═══════════════════════════════════════════════════════════════════════════════
section_scaling() {
    banner "SCREENSHOT: Scaling Table (N=1K to 8M)"
    printf "%-12s %-15s %-15s\n" "N" "Bubble (s)" "Quick (s)"
    echo "────────────────────────────────────────"
    for N in 1000 2000 4000 8000 18250 32000 64000 128000 256000; do
        bubble=$(./mysort_bench $N --bubble-only --csv 2>/dev/null | awk -F, '{print $4}')
        quick=$(./mysort_bench $N --quick-only --csv 2>/dev/null | awk -F, '{print $4}')
        printf "%-12s %-15s %-15s\n" "$N" "$bubble" "$quick"
    done
    for N in 500000 1000000 2000000 4000000 8000000; do
        quick=$(./mysort_bench $N --quick-only --csv 2>/dev/null | awk -F, '{print $4}')
        printf "%-12s %-15s %-15s\n" "$N" "(bubble skip)" "$quick"
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
section_openmp() {
    banner "SCREENSHOT: OpenMP Parallel Quicksort (N=4,000,000)"
    echo "--- Serial quicksort ---"
    ./mysort_bench 4000000 --quick-only --repeat 3
    echo ""
    echo "--- OpenMP quicksort ---"
    ./mysort_omp 4000000 --quick-only --parallel --repeat 3
}

# ═══════════════════════════════════════════════════════════════════════════════
# ── Main dispatch ─────────────────────────────────────────────────────────────
# ═══════════════════════════════════════════════════════════════════════════════

cd "$(dirname "$0")"   # run from Lab01/

# Build first (always needed)
build_all

SECTION="${1:-all}"

case "$SECTION" in
    versions)          section_versions ;;
    perf_O0)           section_perf_O0 ;;
    perf_O2)           section_perf_O2 ;;
    perf_O3)           section_perf_O3 ;;
    cachegrind_bubble) section_cachegrind_bubble ;;
    cachegrind_quick)  section_cachegrind_quick ;;
    gprof_4M)          section_gprof_4M ;;
    scaling)           section_scaling ;;
    openmp)            section_openmp ;;
    all)
        section_versions
        echo ""
        echo "▶ Take screenshot now — VERSIONS"
        read -rp "Press ENTER to continue..." _

        section_perf_O0
        echo ""
        echo "▶ Take screenshot now — PERF STAT O0"
        read -rp "Press ENTER to continue..." _

        section_perf_O2
        echo ""
        echo "▶ Take screenshot now — PERF STAT O2"
        read -rp "Press ENTER to continue..." _

        section_perf_O3
        echo ""
        echo "▶ Take screenshot now — PERF STAT O3"
        read -rp "Press ENTER to continue..." _

        section_cachegrind_bubble
        echo ""
        echo "▶ Take screenshot now — CACHEGRIND BUBBLE"
        read -rp "Press ENTER to continue..." _

        section_cachegrind_quick
        echo ""
        echo "▶ Take screenshot now — CACHEGRIND QUICK"
        read -rp "Press ENTER to continue..." _

        section_gprof_4M
        echo ""
        echo "▶ Take screenshot now — GPROF 4M"
        read -rp "Press ENTER to continue..." _

        section_scaling
        echo ""
        echo "▶ Take screenshot now — SCALING TABLE"
        read -rp "Press ENTER to continue..." _

        section_openmp
        echo ""
        echo "▶ Take screenshot now — OPENMP"
        echo ""
        echo "All done! Add screenshots to Lab01/screenshots/"
        ;;
    *)
        echo "Unknown section: $SECTION"
        echo "Valid: versions perf_O0 perf_O2 perf_O3 cachegrind_bubble cachegrind_quick gprof_4M scaling openmp all"
        exit 1
        ;;
esac
