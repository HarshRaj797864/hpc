#!/usr/bin/env python3
"""
sweep.py — BookSim injection-rate sweep + latency/throughput plot generator
Lab 02: Network-on-Chip Topology Simulation

Usage:
    python3 sweep.py                  # run all 4 sweeps + generate all plots
    python3 sweep.py --topology mesh  # run only mesh sweeps
    python3 sweep.py --dry-run        # print commands without running
    python3 sweep.py --plot-only      # regenerate plots from existing results/

Outputs:
    results/<name>_data.csv     — raw data (injection_rate, latency, throughput)
    plots/<name>_latency.png    — latency vs offered load
    plots/comparison_*.png      — side-by-side comparison plots
"""

import argparse
import csv
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = Path(__file__).parent.resolve()
LAB02_DIR    = SCRIPT_DIR.parent
BOOKSIM      = LAB02_DIR / "booksim2" / "src" / "booksim"
CONFIGS_DIR  = SCRIPT_DIR.parent / "configs"
RESULTS_DIR  = SCRIPT_DIR.parent / "results"
PLOTS_DIR    = SCRIPT_DIR.parent / "plots"

# ── Simulation configurations ─────────────────────────────────────────────────
# injection_rates: 10 data points spanning low-load to near-saturation
SIMULATIONS = [
    {
        "name":    "mesh88_uniform",
        "label":   "8×8 Mesh — Uniform Traffic",
        "config":  "mesh88_uniform.cfg",
        # 20-flit packets; saturation ~0.020; sweep below saturation
        "rates":   [0.001, 0.002, 0.004, 0.006, 0.008, 0.010, 0.012, 0.014, 0.016, 0.018],
        "color":   "#2563eb",
        "marker":  "o",
    },
    {
        "name":    "mesh88_transpose",
        "label":   "8×8 Mesh — Transpose Traffic",
        "config":  "mesh88_transpose.cfg",
        # Transpose is harder on bisection; saturation ~0.008
        "rates":   [0.001, 0.002, 0.003, 0.004, 0.005, 0.006, 0.007, 0.008, 0.009, 0.010],
        "color":   "#dc2626",
        "marker":  "s",
    },
    {
        "name":    "torus88_uniform",
        "label":   "8×8 Torus — Uniform Traffic",
        "config":  "torus88_uniform.cfg",
        # 1-flit packets; saturation ~0.45
        "rates":   [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.38, 0.41, 0.44],
        "color":   "#16a34a",
        "marker":  "^",
    },
    {
        "name":    "torus88_transpose",
        "label":   "8×8 Torus — Transpose Traffic",
        "config":  "torus88_transpose.cfg",
        # Transpose stresses bisection more; saturation ~0.25
        "rates":   [0.02, 0.05, 0.08, 0.11, 0.14, 0.17, 0.20, 0.22, 0.24, 0.26],
        "color":   "#9333ea",
        "marker":  "D",
    },
]

# ── BookSim output parser ─────────────────────────────────────────────────────
def parse_booksim_output(output: str):
    """
    Extract the final average packet latency and accepted throughput from
    BookSim's output. BookSim prints stats after each sample period; we want
    the LAST reported values (the overall averages from the measurement phase).

    Relevant output lines look like:
        Packet latency average = 34.5678
        Accepted packet rate average = 0.0095
    """
    latency    = None
    throughput = None

    # Search for all occurrences and keep the last one (= measurement phase)
    for line in output.splitlines():
        m = re.search(r'Packet latency average\s*=\s*([\d.]+)', line)
        if m:
            latency = float(m.group(1))
        m = re.search(r'Accepted packet rate average\s*=\s*([\d.]+)', line)
        if m:
            throughput = float(m.group(1))

    return latency, throughput


# ── Single simulation run ─────────────────────────────────────────────────────
def run_booksim(config_path: Path, injection_rate: float, dry_run=False):
    """
    Run BookSim with a given config, overriding injection_rate.
    Returns (latency, throughput) or (None, None) on failure.
    """
    # Strip any existing injection_rate lines first — BookSim exits 255 on
    # duplicate/conflicting keys. Then append the sweep value.
    config_text = config_path.read_text()
    clean_lines = [ln for ln in config_text.splitlines()
                   if not ln.strip().startswith("injection_rate")]
    clean_text = "\n".join(clean_lines) + f"\ninjection_rate = {injection_rate};\n"

    with tempfile.NamedTemporaryFile(mode='w', suffix='.cfg',
                                     delete=False, dir='/tmp') as tmp:
        tmp.write(clean_text)
        tmp_path = tmp.name

    cmd = [str(BOOKSIM), tmp_path]

    if dry_run:
        print(f"  [DRY] {' '.join(cmd)}")
        os.unlink(tmp_path)
        return 30.0 + injection_rate * 200, injection_rate * 0.9  # fake data

    try:
        result = subprocess.run(
            cmd,
            capture_output=True, text=True,
            timeout=300,
        )
        os.unlink(tmp_path)

        # BookSim exits with -1 (= code 255) after the drain phase — this is
        # NORMAL behaviour. Always try to parse the output regardless of exit code.
        # Only treat it as a real failure if we can't extract latency from stdout.
        latency, throughput = parse_booksim_output(result.stdout)

        if result.returncode not in (0, 255) and latency is None:
            print(f"    [FAIL] booksim exited {result.returncode}, no parseable output")
            print(result.stdout[-400:])
            return None, None

        if latency is None:
            # True saturation — latency diverged, no final measurement printed
            print(f"    [SATURATED] no stable latency at rate={injection_rate}")
            return None, None
        return latency, throughput

    except subprocess.TimeoutExpired:
        print(f"    [TIMEOUT] rate={injection_rate} exceeded 5 min — network likely saturated")
        os.unlink(tmp_path)
        return None, None
    except Exception as e:
        print(f"    [ERROR] {e}")
        os.unlink(tmp_path)
        return None, None


# ── Sweep one simulation ──────────────────────────────────────────────────────
def sweep(sim: dict, dry_run=False):
    name       = sim["name"]
    config     = CONFIGS_DIR / sim["config"]
    rates      = sim["rates"]
    csv_path   = RESULTS_DIR / f"{name}_data.csv"

    print(f"\n{'='*60}")
    print(f"  Sweeping: {sim['label']}")
    print(f"  Config:   {config}")
    print(f"  Rates:    {rates}")
    print(f"{'='*60}")

    rows = []
    for rate in rates:
        print(f"  → injection_rate = {rate:.4f} ... ", end='', flush=True)
        lat, tput = run_booksim(config, rate, dry_run=dry_run)
        if lat is not None:
            print(f"latency = {lat:.2f} cycles,  throughput = {tput:.5f}")
            rows.append({"injection_rate": rate, "latency": lat, "throughput": tput})
        else:
            print("SKIPPED (saturated or error)")

    # Save CSV
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    with open(csv_path, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=["injection_rate", "latency", "throughput"])
        w.writeheader()
        w.writerows(rows)
    print(f"\n  Saved: {csv_path}  ({len(rows)} data points)")
    return rows


# ── Plot one simulation ───────────────────────────────────────────────────────
def plot_single(sim: dict, rows: list, show=False):
    import matplotlib.pyplot as plt
    import matplotlib.ticker as ticker

    name  = sim["name"]
    label = sim["label"]

    rates    = [r["injection_rate"] for r in rows]
    latency  = [r["latency"]        for r in rows]
    tput     = [r["throughput"]     for r in rows]

    fig, ax1 = plt.subplots(figsize=(8, 5))

    # Latency line
    color_lat = sim["color"]
    ax1.plot(rates, latency, color=color_lat, marker=sim["marker"],
             linewidth=2, markersize=7, label="Avg Packet Latency (cycles)")
    ax1.set_xlabel("Offered Load (Injection Rate, packets/cycle/node)", fontsize=12)
    ax1.set_ylabel("Average Packet Latency (cycles)", color=color_lat, fontsize=12)
    ax1.tick_params(axis='y', labelcolor=color_lat)
    ax1.yaxis.set_minor_locator(ticker.AutoMinorLocator())
    ax1.grid(True, which='major', linestyle='--', alpha=0.5)

    # Throughput on secondary axis
    ax2 = ax1.twinx()
    color_tput = "#f59e0b"
    ax2.plot(rates, tput, color=color_tput, marker='x',
             linewidth=1.5, markersize=6, linestyle='--',
             label="Accepted Throughput (packets/cycle/node)")
    ax2.set_ylabel("Accepted Throughput (packets/cycle/node)",
                   color=color_tput, fontsize=11)
    ax2.tick_params(axis='y', labelcolor=color_tput)

    # Combined legend
    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax1.legend(lines1 + lines2, labels1 + labels2,
               loc='upper left', fontsize=9, framealpha=0.9)

    plt.title(f"Latency vs Offered Load\n{label}", fontsize=13, fontweight='bold', pad=12)
    fig.tight_layout()

    PLOTS_DIR.mkdir(parents=True, exist_ok=True)
    out = PLOTS_DIR / f"{name}_latency.png"
    plt.savefig(out, dpi=150, bbox_inches='tight')
    print(f"  Plot saved: {out}")
    if show:
        plt.show()
    plt.close()
    return out


# ── Comparison plots ──────────────────────────────────────────────────────────
def plot_comparison(sims_data: list, topology: str, show=False):
    """Overlay both traffic patterns for one topology on one figure."""
    import matplotlib.pyplot as plt

    subset = [(s, d) for s, d in sims_data if topology in s["name"] and d]
    if not subset:
        return

    fig, ax = plt.subplots(figsize=(9, 5.5))

    for sim, rows in subset:
        rates   = [r["injection_rate"] for r in rows]
        latency = [r["latency"]        for r in rows]
        ax.plot(rates, latency,
                color=sim["color"], marker=sim["marker"],
                linewidth=2, markersize=7,
                label=sim["label"].split("—")[1].strip())

    topo_label = "8×8 Mesh" if topology == "mesh" else "8×8 Torus"
    ax.set_xlabel("Offered Load (Injection Rate, packets/cycle/node)", fontsize=12)
    ax.set_ylabel("Average Packet Latency (cycles)", fontsize=12)
    ax.set_title(f"Latency vs Offered Load — {topo_label}\nUniform vs Transpose Traffic",
                 fontsize=13, fontweight='bold', pad=12)
    ax.legend(fontsize=10, framealpha=0.9)
    ax.grid(True, linestyle='--', alpha=0.5)
    fig.tight_layout()

    out = PLOTS_DIR / f"comparison_{topology}.png"
    plt.savefig(out, dpi=150, bbox_inches='tight')
    print(f"  Comparison plot: {out}")
    if show:
        plt.show()
    plt.close()


def plot_mesh_vs_torus(sims_data: list, show=False):
    """Overlay mesh-uniform vs torus-uniform for direct topology comparison."""
    import matplotlib.pyplot as plt

    want = {"mesh88_uniform", "torus88_uniform"}
    subset = [(s, d) for s, d in sims_data if s["name"] in want and d]
    if len(subset) < 2:
        return

    fig, ax = plt.subplots(figsize=(9, 5.5))
    for sim, rows in subset:
        rates   = [r["injection_rate"] for r in rows]
        latency = [r["latency"]        for r in rows]
        ax.plot(rates, latency,
                color=sim["color"], marker=sim["marker"],
                linewidth=2, markersize=7, label=sim["label"])

    ax.set_xlabel("Offered Load (Injection Rate, packets/cycle/node)", fontsize=12)
    ax.set_ylabel("Average Packet Latency (cycles)", fontsize=12)
    ax.set_title("Mesh vs Torus — Uniform Traffic Comparison",
                 fontsize=13, fontweight='bold', pad=12)
    ax.legend(fontsize=10, framealpha=0.9)
    ax.grid(True, linestyle='--', alpha=0.5)
    fig.tight_layout()

    out = PLOTS_DIR / "comparison_mesh_vs_torus.png"
    plt.savefig(out, dpi=150, bbox_inches='tight')
    print(f"  Mesh vs Torus plot: {out}")
    if show:
        plt.show()
    plt.close()


# ── Load existing CSV results ─────────────────────────────────────────────────
def load_csv(sim: dict):
    csv_path = RESULTS_DIR / f"{sim['name']}_data.csv"
    if not csv_path.exists():
        print(f"  [WARN] No results for {sim['name']} — run sweep first")
        return []
    rows = []
    with open(csv_path) as f:
        for row in csv.DictReader(f):
            rows.append({
                "injection_rate": float(row["injection_rate"]),
                "latency":        float(row["latency"]),
                "throughput":     float(row["throughput"]),
            })
    return rows


# ── CLI ───────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="BookSim sweep + plot for Lab02")
    parser.add_argument("--topology", choices=["mesh", "torus", "all"],
                        default="all", help="Which topology to sweep")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print commands without running BookSim")
    parser.add_argument("--plot-only", action="store_true",
                        help="Skip sweep, regenerate plots from existing CSVs")
    parser.add_argument("--show", action="store_true",
                        help="Show plots interactively (needs display)")
    args = parser.parse_args()

    # Check BookSim binary exists
    if not args.plot_only and not args.dry_run:
        if not BOOKSIM.exists():
            print(f"ERROR: booksim binary not found at {BOOKSIM}")
            print("Run: cd Lab02/booksim2/src && make -j$(nproc)")
            sys.exit(1)

    # Filter simulations by topology
    sims = SIMULATIONS
    if args.topology == "mesh":
        sims = [s for s in SIMULATIONS if "mesh" in s["name"]]
    elif args.topology == "torus":
        sims = [s for s in SIMULATIONS if "torus" in s["name"]]

    sims_data = []
    for sim in sims:
        if args.plot_only:
            rows = load_csv(sim)
        else:
            rows = sweep(sim, dry_run=args.dry_run)

        if rows:
            print(f"\nGenerating plot for {sim['label']}...")
            plot_single(sim, rows, show=args.show)

        sims_data.append((sim, rows))

    # Comparison plots
    print("\nGenerating comparison plots...")
    plot_comparison(sims_data, "mesh",  show=args.show)
    plot_comparison(sims_data, "torus", show=args.show)
    plot_mesh_vs_torus(sims_data, show=args.show)

    print("\n✅ Done. Results in:")
    print(f"   {RESULTS_DIR}/")
    print(f"   {PLOTS_DIR}/")


if __name__ == "__main__":
    main()
