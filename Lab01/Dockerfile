###############################################################################
# Lab01 — Performance Profiling and Optimization (GPROF + PERF)
#
# PURPOSE
#   Build a self-contained Ubuntu 22.04 image that can reproduce every
#   experiment in README.md §2–§10 and emit all result files.
#
# BUILD
#   docker build -t hpc-lab01 .
#
# RUN (basic — software perf counters only, same as WSL2)
#   docker run --rm -v "$(pwd)/results:/lab/results" hpc-lab01
#
# RUN (full — hardware PMU counters, cycles, IPC, cache-misses)
#   docker run --rm --privileged -v "$(pwd)/results:/lab/results" hpc-lab01
#
#   --privileged passes /dev/cpu/* and the perf_event subsystem through to
#   the container. Requires the HOST kernel to have a real PMU (i.e. native
#   Linux, NOT WSL2/Hyper-V). On WSL2 you will still get the software
#   counters; hardware rows will print <not supported>.
#
# OUTPUT
#   All result files are written to /lab/results/ inside the container, which
#   is bind-mounted to ./results/ on the host.
###############################################################################

FROM ubuntu:22.04

# ── Labels ─────────────────────────────────────────────────────────────────
LABEL maintainer="Harsh Raj <rajharsh797864@gmail.com>"
LABEL description="Lab01 HPC profiling environment — gprof, perf, valgrind/cachegrind"

# ── Non-interactive apt ─────────────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive

# ── Install all required tooling in one layer ───────────────────────────────
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        make \
        binutils \
        linux-tools-generic \
        linux-tools-common \
        valgrind \
        time \
        bc \
        procps \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Set up working directory ─────────────────────────────────────────────────
WORKDIR /lab

# ── Copy source (only what is needed — no binaries, no gmon.out) ────────────
COPY mysort.c     ./
COPY run_lab.sh   ./

# ── Make the run script executable ──────────────────────────────────────────
RUN chmod +x run_lab.sh

# ── Create the output directory ──────────────────────────────────────────────
RUN mkdir -p results

# ── perf: resolve the versioned binary at build time ─────────────────────────
RUN PERF_BIN=$(ls /usr/lib/linux-tools-*/perf 2>/dev/null | head -1) && \
    if [ -n "$PERF_BIN" ]; then \
        ln -sf "$PERF_BIN" /usr/local/bin/perf_lab; \
    else \
        echo "WARNING: perf binary not found"; \
    fi

# ── Expose PERF path as env var for the run script ──────────────────────────
ENV PERF=/usr/local/bin/perf_lab

# ── Default entrypoint ───────────────────────────────────────────────────────
ENTRYPOINT ["bash", "run_lab.sh"]
