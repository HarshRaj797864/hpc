#!/usr/bin/env bash
# .devcontainer/setup.sh
# Runs once after the Codespace container is created.
# Sets up perf access and prints environment info.

set -euo pipefail

echo "══════════════════════════════════════════"
echo " HPC Lab — Codespace Setup"
echo "══════════════════════════════════════════"

# ── Lower perf_event_paranoid (allows HW counters without full root) ───────
# -1 = unrestricted, 0 = allow HW events, 1 = allow SW events only (default), 2 = deny all
if [ -w /proc/sys/kernel/perf_event_paranoid ]; then
    echo -1 | tee /proc/sys/kernel/perf_event_paranoid
    echo "[OK] perf_event_paranoid set to -1"
else
    echo "[WARN] Cannot set perf_event_paranoid (may need --privileged)"
fi

# ── Resolve the perf binary ────────────────────────────────────────────────
PERF_BIN=$(ls /usr/lib/linux-tools-*/perf 2>/dev/null | head -1 || which perf 2>/dev/null || true)
if [ -n "$PERF_BIN" ]; then
    echo "export PERF=$PERF_BIN" >> /etc/environment
    echo "export PERF=$PERF_BIN" >> /root/.bashrc
    echo "[OK] PERF=$PERF_BIN"
else
    echo "[WARN] perf binary not found"
fi

# ── Print environment snapshot ─────────────────────────────────────────────
echo ""
echo "── Kernel: $(uname -r)"
echo "── CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "── Cores: $(nproc)"
echo "── GCC: $(gcc --version | head -1)"
echo "── valgrind: $(valgrind --version 2>&1 | head -1)"
[ -n "${PERF_BIN:-}" ] && echo "── perf: $($PERF_BIN --version 2>&1 | head -1)"

# ── Test perf hardware counter availability ────────────────────────────────
echo ""
echo "── PMU probe:"
cat > /tmp/perf_probe.c << 'PROBE'
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
    printf("   %-22s : %s\n", name, fd < 0 ? strerror(errno) : "OK ✓");
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
PROBE

gcc -O0 /tmp/perf_probe.c -o /tmp/perf_probe 2>/dev/null && /tmp/perf_probe || echo "   (probe build failed)"

echo ""
echo "══════════════════════════════════════════"
echo " Setup complete. Open a terminal and run:"
echo "   cd /workspace/Lab01"
echo "   bash perf_screenshots.sh"
echo "══════════════════════════════════════════"
