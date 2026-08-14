---
title: "Lab 02 — Network-on-Chip Topology Simulation using BookSim2"
subtitle: "Mesh vs Torus: Latency vs Offered Load Analysis"
author: "Harsh Raj"
date: "August 2026"
---

# Lab 02 — Network-on-Chip Simulation

## Task 1 — Reading Questions

### 1. What is a Topology?

A **network topology** is the graph structure that defines how nodes (processors / switches) are interconnected — specifically which nodes are directly connected by links. It determines:
- **Diameter** — the maximum shortest path between any two nodes (directly impacts worst-case latency)
- **Radix** — the number of ports (connections) on each router/switch
- **Bisection bandwidth** — the minimum bandwidth across any cut that splits the network in half
- **Scalability** — how cost and performance scale as nodes are added

Topologies are classified as:
| Class | Description | Examples |
|-------|-------------|---------|
| **Direct** | Every node is both a terminal AND a switch | Mesh, Torus, Hypercube |
| **Indirect** | Nodes are either switches OR terminals (not both) | Fat-Tree, Butterfly, Omega |

---

### 2. What is an Interconnect Network and Network-on-Chip (NoC)?

**Interconnect Network**: A system of links, switches/routers, and interfaces that carries data between processing elements in a parallel computer. It is the "communication fabric" — without it, processors cannot share data or coordinate work.

**Network-on-Chip (NoC)**: An interconnect network implemented *entirely on a single chip* (die). Instead of off-chip wires and connectors, NoC uses:
- **On-chip routers** (small, fast, low-power)
- **On-chip links** (metal wires between router tiles)
- **Network interfaces** (connect processor cores to routers)

NoC replaced traditional shared buses in many-core processors because buses do not scale — bandwidth is fixed and contention grows with core count. NoC provides:
- **Scalable bandwidth**: each node adds local bandwidth
- **Predictable latency**: hop-by-hop pipelining
- **Energy efficiency**: short on-chip wires consume less power than long bus wires

---

### 3. Difference Between Mesh, Torus, and Fat-Tree

| Property | **Mesh** | **Torus** | **Fat-Tree** |
|-----------|----------|-----------|--------------|
| **Type** | Direct | Direct | Indirect |
| **Topology** | 2D grid, no wrap-around | 2D grid + wrap-around links | Hierarchical tree with wider links near root |
| **Diameter (N=k²)** | 2(k−1) | k | 2·log_r(N) |
| **8×8 diameter** | 14 hops | 7 hops | 6 hops (for k=8 fat-tree) |
| **Bisection BW** | k links | 2k links | Full (N/2 links) |
| **Radix per router** | 4 (2D) | 4+wrap | Varies by level |
| **Routing** | DOR (simple, deadlock-free) | DOR + 2 VCs (needs VCs to avoid deadlock) | Up-down routing |
| **Wiring cost** | Low (local links only) | Medium (wrap-around wires are long at corners) | High (many long wires at upper levels) |
| **Typical use** | On-chip NoC (Intel Xeon Phi, Tilera) | HPC clusters, Cray machines | Data-centre networks, HPC (IBM BlueGene) |

**Key insight**: Torus adds wrap-around links to the mesh, halving the diameter and doubling bisection bandwidth at modest extra wiring cost. Fat-Tree achieves *full bisection bandwidth* (no bisection bottleneck) but requires expensive, long inter-switch cables.

---

### 4. Radix, Bisection Bandwidth, and Network Latency

#### Radix
The **radix** (or degree) of a router is the number of physical ports it has — including both network ports (to other routers) and injection ports (to the local processor core). Higher radix means each router can connect to more neighbours, reducing diameter but increasing router complexity (more ports = larger crossbar).

- 2D Mesh router: radix = 4 (N, S, E, W) + 1 local = 5
- Fat-tree switch: radix = 2r (r down-ports + r up-ports)

#### Bisection Bandwidth
The **bisection bandwidth (BB)** is the *minimum* total bandwidth across any cut that divides the network into two equal halves. It represents the worst-case bottleneck for all-to-all communication patterns.

```
BB = min over all bisections of: Σ (bandwidth of channels crossing the cut)
```

| Network | Bisection bandwidth (N=64 nodes, link BW = b) |
|---------|-----------------------------------------------|
| 8×8 Mesh | 8b (only 8 links cross the midline) |
| 8×8 Torus | 16b (8 links each direction × 2 directions) |
| Fat-Tree | 32b (full bisection = N/2 × b) |

Higher bisection bandwidth → better all-to-all throughput → less congestion under adversarial traffic.

#### Network Latency
**Network latency** is the time from when a packet is injected at the source until the last flit is accepted at the destination. It has three components:

```
Total Latency = Serialization delay + Routing/pipeline delay + Queuing delay
```

1. **Serialization delay**: time to transmit all flits of a packet over a link = `packet_size × link_cycles`
2. **Routing/pipeline delay**: fixed overhead per hop = `(routing_delay + vc_alloc_delay + sw_alloc_delay) × hops`
3. **Queuing delay**: waiting for VCs/switches when congested — grows sharply as load → saturation point

At **low load**, queuing ≈ 0 so latency ≈ serialization + pipeline.  
At **high load** (near saturation), queuing dominates and latency → ∞.

---

## Task 2 — Simulation Results

### Setup

| Parameter | Mesh | Torus |
|-----------|------|-------|
| Topology | 8×8 mesh (k=8, n=2) | 8×8 torus (k=8, n=2) |
| Nodes | 64 | 64 |
| Routing | DOR (X→Y) | Dimension-Order |
| Virtual Channels | 8 | 2 (minimum for deadlock-free DOR on torus) |
| Packet size | 20 flits | 1 flit |
| VC allocator | iSLIP | iSLIP |
| Simulator | BookSim 2.0 | BookSim 2.0 |
| Traffic | Uniform, Transpose | Uniform, Transpose |
| Data points | 10 per curve | 10 per curve |

### Plot 1 — 8×8 Mesh, Uniform Traffic

**Config**: [`configs/mesh88_uniform.cfg`](configs/mesh88_uniform.cfg)

| Injection Rate | Avg Latency (cycles) | Throughput |
|---------------|---------------------|------------|
| 0.001 | 47.42 | 0.00095 |
| 0.002 | 49.12 | 0.00197 |
| 0.004 | 52.73 | 0.00390 |
| 0.006 | 57.34 | 0.00573 |
| 0.008 | 62.86 | 0.00769 |
| 0.010 | 72.38 | 0.00981 |
| 0.012 | 76.43 | 0.01172 |
| 0.014 | 87.01 | 0.01372 |
| 0.016 | 107.30 | 0.01576 |
| 0.018 | 140.54 | 0.01772 |

**Interpretation**: At low load (0.001), the zero-load latency is ~47 cycles = 6.2 average hops × (~5 cycles pipeline overhead per hop) + 20 flits serialization ≈ correct. Latency rises smoothly, accelerating sharply after rate ≈ 0.016. The network approaches saturation around 0.020 packets/cycle/node — consistent with the theoretical bisection bandwidth limit of the 8×8 mesh.

---

### Plot 2 — 8×8 Mesh, Transpose Traffic

**Config**: [`configs/mesh88_transpose.cfg`](configs/mesh88_transpose.cfg)

| Injection Rate | Avg Latency (cycles) | Throughput |
|---------------|---------------------|------------|
| 0.001 | 46.75 | 0.00095 |
| 0.002 | 48.00 | 0.00196 |
| 0.003 | 52.65 | 0.00294 |
| 0.004 | 55.96 | 0.00392 |
| 0.005 | 62.83 | 0.00475 |
| 0.006 | 72.83 | 0.00577 |
| 0.007 | 133.81 | 0.00679 |
| 0.008 | 323.01 | 0.00760 |
| 0.009 | 332.07 | 0.00824 |
| 0.010 | 248.69 | 0.00900 |

**Interpretation**: Transpose traffic maps node (x,y)→(y,x), which forces all traffic to cross the network bisection. This stresses the fewest bisection links (only 8 in a mesh), causing saturation at ≈0.007 — **less than half the saturation rate of uniform traffic**. The dramatic latency spike from 73→323 cycles between rates 0.006 and 0.008 is the classic "knee" of the latency curve, marking the saturation point.

---

### Plot 3 — 8×8 Torus, Uniform Traffic

**Config**: [`configs/torus88_uniform.cfg`](configs/torus88_uniform.cfg)

| Injection Rate | Avg Latency (cycles) | Throughput |
|---------------|---------------------|------------|
| 0.05 | 31.51 | 0.0506 |
| 0.10 | 32.34 | 0.1000 |
| 0.15 | 33.66 | 0.1504 |
| 0.20 | 36.16 | 0.2001 |
| 0.25 | 44.20 | 0.2493 |
| 0.30 | 505.37 | 0.2524 |
| 0.35 | 679.11 | 0.2103 |
| 0.38 | 834.85 | 0.2198 |
| 0.41 | 964.40 | 0.2151 |
| 0.44 | 1078.84 | 0.2129 |

**Interpretation**: The torus with 1-flit packets shows a very flat latency curve from 0.05–0.25 (31–44 cycles) — low and almost constant because single-flit packets have zero serialization overhead. The saturation "knee" occurs sharply between 0.25 and 0.30, where latency jumps from 44 to 505 cycles. The saturated throughput plateaus at ~0.25 packets/cycle/node, consistent with the torus bisection limit.

---

### Plot 4 — 8×8 Torus, Transpose Traffic

**Config**: [`configs/torus88_transpose.cfg`](configs/torus88_transpose.cfg)

| Injection Rate | Avg Latency (cycles) | Throughput |
|---------------|---------------------|------------|
| 0.02 | 31.36 | 0.0197 |
| 0.05 | 32.53 | 0.0506 |
| 0.08 | 37.98 | 0.0800 |
| 0.11 | 492.00 | 0.0986 |
| 0.14 | 398.77 | 0.1071 |
| 0.17 | 412.16 | 0.1151 |
| 0.20 | 438.11 | 0.1203 |
| 0.22 | 452.56 | 0.1231 |
| 0.24 | 521.57 | 0.1282 |
| 0.26 | 568.41 | 0.1319 |

**Interpretation**: Transpose traffic saturates the torus at ≈0.09 — lower than uniform traffic (0.28) but still much higher than the mesh under transpose (0.007). The torus's wrap-around links double the bisection bandwidth, allowing it to handle transpose traffic significantly better than the mesh. The throughput plateaus at ~0.13, reflecting the torus bisection limit under this adversarial pattern.

---

### Key Comparative Findings

| Metric | Mesh (Uniform) | Mesh (Transpose) | Torus (Uniform) | Torus (Transpose) |
|--------|---------------|-----------------|----------------|-------------------|
| Zero-load latency | ~47 cycles | ~47 cycles | ~31 cycles | ~31 cycles |
| Saturation rate | ~0.020 | ~0.007 | ~0.28 | ~0.09 |
| Sat. throughput | ~0.018 | ~0.008 | ~0.25 | ~0.13 |

**Conclusions:**
1. **Torus has lower zero-load latency than mesh** because wrap-around links shorten average hop count (7 vs 14 max hops for 8×8)
2. **Torus saturates at much higher offered load** — its 2× bisection bandwidth (16 vs 8 links) directly doubles throughput under uniform traffic
3. **Transpose is adversarial for both topologies** — it maximally stresses bisection bandwidth, reducing saturation threshold by 3–5× compared to uniform
4. **Mesh is more sensitive to traffic pattern** — transpose cuts mesh capacity to 35% of uniform, vs torus where it cuts to 32% — similar ratio but from a higher absolute baseline

---

## Running the Simulations

### Local (WSL2 / Linux)

```bash
# Build BookSim2
cd Lab02/booksim2/src && make -j$(nproc)

# Run the full sweep (all 4 topologies, 10 data points each)
cd Lab02
python3 scripts/sweep.py

# Run only mesh sweeps
python3 scripts/sweep.py --topology mesh

# Regenerate plots from existing CSV data
python3 scripts/sweep.py --plot-only
```

### GitHub Codespaces

1. Open the repo at `https://github.com/HarshRaj797864/hpc`
2. Click **Code → Codespaces → Create codespace on main**
3. Wait for container to build (uses `.devcontainer/devcontainer.json`)
4. In the terminal:
   ```bash
   cd /workspace/Lab02/booksim2/src && make -j$(nproc)
   cd /workspace/Lab02
   python3 scripts/sweep.py
   ```
5. View plots in `Lab02/plots/` — right-click → Download to save screenshots

### How to Use BookSim Directly

```bash
# Single simulation run
./booksim2/src/booksim configs/mesh88_uniform.cfg

# Key output lines to look for:
#   Packet latency average = XX.XX     ← average end-to-end latency in cycles
#   Accepted packet rate average = XX  ← actual throughput (≤ injection_rate at saturation)
#   Hops average = XX                  ← confirms routing path length

# Modify injection_rate in config or pass override:
echo "injection_rate = 0.01;" >> /tmp/my.cfg
cat configs/mesh88_uniform.cfg >> /tmp/my.cfg
./booksim2/src/booksim /tmp/my.cfg
```

---

## Task 3 (Optional) — Indirect Topologies: Fat-Tree and Butterfly

BookSim includes example configs for both:
- **Fat-Tree**: `booksim2/src/examples/fattree_config`
- **Butterfly (k-ary n-fly)**: configured via `topology = fly`

To explore:
```bash
./booksim2/src/booksim booksim2/src/examples/fattree_config
```

Fat-Tree has **full bisection bandwidth** — it does NOT degrade under transpose traffic. This would show as flat/high saturation point for both uniform and transpose, contrasting sharply with mesh and torus.
