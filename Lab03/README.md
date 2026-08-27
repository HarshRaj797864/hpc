# Lab 03: Parallel Programming with Pthreads

This repository contains the solutions, code, and analysis for **Lab 03**.

## Directory Structure
- `q1_pi/`: Source code and runner for Question 1 (Monte Carlo Pi Estimation)
- `q2_edge/`: Source code and runner for Question 2 (Parallel Edge Detection)
- `q3_philosophers/`: Source code for Question 3 (Dining Philosophers)
- `plots/`: Generated benchmark graphs for Q1 and Q2.
- `results/`: CSV files containing raw benchmark data.

---

## Question 1: Monte Carlo Estimation of π Using Pthreads

### Overview
A parallel implementation to estimate the value of $\pi$ using the Monte Carlo method. The program generates random points in a square and counts how many fall within the inscribed circle.

### Execution
The python script `run_q1.py` sweeps over:
- **Points**: $10, 10^2, 10^4, 10^6, 10^7, 10^8, 10^9$
- **Threads**: $1, 2, 4, 8, 16$

### Results and Graphs
Please refer to the `plots/` directory for the following generated graphs:
1. `q1_points_vs_pi.png`: Number of points vs. estimated $\pi$
2. `q1_points_vs_error.png`: Number of points vs. absolute error
3. `q1_threads_vs_time.png`: Threads vs. Execution time
4. `q1_threads_vs_speedup.png`: Threads vs. Speedup
5. `q1_threads_vs_efficiency.png`: Threads vs. Efficiency

*Observation:* As the number of points increases, the estimated value of $\pi$ converges to the actual value, and the error drops significantly. As threads increase, execution time decreases, though efficiency drops slightly due to thread creation and synchronization overhead.

---

## Question 2: Parallel Edge Detection Using Pthreads

### Overview
Edge detection on an $8192 \times 8192$ matrix using a $3 \times 3$ Sobel template. The image rows are divided evenly among threads to compute the gradients concurrently.

### Discussion Questions

**1. How does increasing the number of Pthreads affect execution time?**
Increasing the number of threads generally decreases the execution time because the workload (processing rows of the image) is divided among multiple concurrent threads. However, this is only true up to the number of physical cores available on the machine. Beyond that, context switching overhead and memory bandwidth contention will cause execution time to plateau or even increase.

**2. Does the speedup increase linearly with the number of threads? Explain.**
Ideally, yes (linear speedup). In reality, no. Amdahl's Law dictates that the sequential portion of the program limits the maximum theoretical speedup. Additionally, overhead from thread creation, scheduling, and memory bus contention (since all threads access the shared image matrix) causes the actual speedup to grow sub-linearly and eventually flatten.

**3. What factors limit the achievable speedup?**
Several factors limit speedup:
- **Hardware limits:** The number of physical CPU cores.
- **Memory bandwidth:** Multiple threads reading/writing to the shared massive image matrix can saturate the RAM bandwidth (making it a memory-bound problem).
- **Thread overhead:** Time taken to create, schedule, and join threads.
- **Sequential bottlenecks:** Code that cannot be parallelized (e.g., memory allocation, array initialization, thread spawning).

**4. Why can efficiency decrease as the number of threads increases?**
Efficiency is defined as `Speedup / Number_of_threads`. Since speedup grows sub-linearly due to the overheads mentioned above (synchronization, context switching, memory contention), the numerator (Speedup) does not keep pace with the denominator (Threads). Therefore, adding more threads results in diminishing returns per thread, lowering overall efficiency.

**5. Compare the performance of the serial and Pthreads implementations.**
The serial implementation executes the edge detection iteratively on a single core, establishing the baseline execution time. The Pthreads implementation distributes the row processing across multiple cores, resulting in a significantly lower execution time. The parallel version showcases how compute-heavy tasks over large independent matrices greatly benefit from shared-memory parallelization, achieving near-linear speedup for lower thread counts (e.g., 2 to 4 threads).

---

## Question 3: Dining Philosophers Problem

### Overview
This directory contains two C files demonstrating the Dining Philosophers synchronization problem.

1. **`dining_deadlock.c` (Naive Solution):** 
   Implements "Solution 1" where every philosopher picks up the left chopstick, then the right chopstick. This introduces a circular dependency and easily leads to a deadlock.
   
2. **`dining_safe.c` (Asymmetric Solution):** 
   A deadlock-free solution. Even-numbered philosophers pick up the left chopstick first, while odd-numbered philosophers pick up the right chopstick first. This breaks the circular wait condition.

### How to Run
```bash
cd q3_philosophers
make
./dining_deadlock   # Will likely freeze (deadlock)
./dining_safe       # Will run successfully to completion
```
