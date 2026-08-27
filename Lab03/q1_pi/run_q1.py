import subprocess
import os
import math
import csv
import matplotlib.pyplot as plt

# Ensure compiled
subprocess.run(['make', 'clean'], cwd='.')
subprocess.run(['make'], cwd='.')

points_list = [10, 100, 10000, 1000000, 10000000, 100000000, 1000000000]
threads_list = [1, 2, 4, 8, 16]

ACTUAL_PI = math.pi

# --- 1. Fix threads to 4, vary points (for Pi estimation accuracy) ---
results_points = []
print("Running Points vs Pi/Error experiments...")
for pts in points_list:
    print(f"Points: {pts}")
    result = subprocess.run(['./pi_parallel', str(pts), '4'], capture_output=True, text=True)
    pi_est, time_taken = map(float, result.stdout.strip().split())
    error = abs(ACTUAL_PI - pi_est)
    results_points.append({
        'Points': pts,
        'Pi_Est': pi_est,
        'Error': error,
        'Time': time_taken
    })

# --- 2. Fix points to 10^9, vary threads (for Speedup/Efficiency) ---
results_threads = []
fixed_points = 1000000000
print(f"Running Threads vs Time/Speedup/Efficiency (Points: {fixed_points})...")
# Run Serial
print("Running Serial...")
res_serial = subprocess.run(['./pi_serial', str(fixed_points)], capture_output=True, text=True)
pi_serial, serial_time = map(float, res_serial.stdout.strip().split())

for t in threads_list:
    print(f"Threads: {t}")
    result = subprocess.run(['./pi_parallel', str(fixed_points), str(t)], capture_output=True, text=True)
    pi_est, time_taken = map(float, result.stdout.strip().split())
    speedup = serial_time / time_taken if time_taken > 0 else 0
    efficiency = speedup / t
    results_threads.append({
        'Threads': t,
        'Time': time_taken,
        'Speedup': speedup,
        'Efficiency': efficiency
    })

# Save to CSV
os.makedirs('../results', exist_ok=True)
os.makedirs('../plots', exist_ok=True)

with open('../results/q1_points.csv', 'w') as f:
    writer = csv.DictWriter(f, fieldnames=['Points', 'Pi_Est', 'Error', 'Time'])
    writer.writeheader()
    writer.writerows(results_points)

with open('../results/q1_threads.csv', 'w') as f:
    writer = csv.DictWriter(f, fieldnames=['Threads', 'Time', 'Speedup', 'Efficiency'])
    writer.writeheader()
    writer.writerows(results_threads)

# --- Plotting ---
print("Generating plots...")
pts = [r['Points'] for r in results_points]
pi_ests = [r['Pi_Est'] for r in results_points]
errors = [r['Error'] for r in results_points]

th = [r['Threads'] for r in results_threads]
times = [r['Time'] for r in results_threads]
speedups = [r['Speedup'] for r in results_threads]
efficiencies = [r['Efficiency'] for r in results_threads]

# 1. Number of points vs estimated Pi
plt.figure()
plt.plot(pts, pi_ests, marker='o')
plt.axhline(y=ACTUAL_PI, color='r', linestyle='--', label='Actual Pi')
plt.xscale('log')
plt.xlabel('Number of Points')
plt.ylabel('Estimated Pi')
plt.title('Points vs Estimated Pi')
plt.legend()
plt.savefig('../plots/q1_points_vs_pi.png')
plt.close()

# 2. Number of points vs error
plt.figure()
plt.plot(pts, errors, marker='s', color='orange')
plt.xscale('log')
plt.yscale('log')
plt.xlabel('Number of Points')
plt.ylabel('Absolute Error')
plt.title('Points vs Error')
plt.savefig('../plots/q1_points_vs_error.png')
plt.close()

# 3. Threads vs Execution Time
plt.figure()
plt.plot(th, times, marker='o', color='green')
plt.axhline(y=serial_time, color='r', linestyle='--', label='Serial Time')
plt.xlabel('Number of Threads')
plt.ylabel('Execution Time (s)')
plt.title('Threads vs Execution Time')
plt.xticks(th)
plt.legend()
plt.savefig('../plots/q1_threads_vs_time.png')
plt.close()

# 4. Threads vs Speedup
plt.figure()
plt.plot(th, speedups, marker='o', color='purple')
plt.plot(th, th, 'k--', label='Ideal Speedup')
plt.xlabel('Number of Threads')
plt.ylabel('Speedup')
plt.title('Threads vs Speedup')
plt.xticks(th)
plt.legend()
plt.savefig('../plots/q1_threads_vs_speedup.png')
plt.close()

# 5. Threads vs Efficiency
plt.figure()
plt.plot(th, efficiencies, marker='o', color='brown')
plt.axhline(y=1.0, color='k', linestyle='--', label='Ideal Efficiency')
plt.xlabel('Number of Threads')
plt.ylabel('Efficiency')
plt.title('Threads vs Efficiency')
plt.xticks(th)
plt.ylim(0, 1.2)
plt.legend()
plt.savefig('../plots/q1_threads_vs_efficiency.png')
plt.close()

print("Q1 Done.")
