import subprocess
import os
import csv
import matplotlib.pyplot as plt

subprocess.run(['make', 'clean'], cwd='.')
subprocess.run(['make'], cwd='.')

threads_list = [1, 2, 4, 8, 16]
results = []

print("Running Serial Edge Detection...")
res_serial = subprocess.run(['./edge_serial'], capture_output=True, text=True)
serial_time = float(res_serial.stdout.strip())
print(f"Serial Time: {serial_time:.4f}s")

for t in threads_list:
    print(f"Running Parallel Edge Detection with {t} threads...")
    res = subprocess.run(['./edge_parallel', str(t)], capture_output=True, text=True)
    time_taken = float(res.stdout.strip())
    speedup = serial_time / time_taken if time_taken > 0 else 0
    efficiency = speedup / t
    results.append({
        'Threads': t,
        'Time': time_taken,
        'Speedup': speedup,
        'Efficiency': efficiency
    })

os.makedirs('../results', exist_ok=True)
os.makedirs('../plots', exist_ok=True)

with open('../results/q2_edge.csv', 'w') as f:
    writer = csv.DictWriter(f, fieldnames=['Threads', 'Time', 'Speedup', 'Efficiency'])
    writer.writeheader()
    writer.writerows(results)

th = [r['Threads'] for r in results]
times = [r['Time'] for r in results]
speedups = [r['Speedup'] for r in results]
efficiencies = [r['Efficiency'] for r in results]

# Plot 1: Threads vs Execution Time
plt.figure()
plt.plot(th, times, marker='o', color='blue')
plt.axhline(y=serial_time, color='r', linestyle='--', label='Serial Time')
plt.xlabel('Number of Threads')
plt.ylabel('Parallel Execution Time (s)')
plt.title('Threads vs Execution Time')
plt.xticks(th)
plt.legend()
plt.savefig('../plots/q2_threads_vs_time.png')
plt.close()

# Plot 2: Threads vs Speedup
plt.figure()
plt.plot(th, speedups, marker='o', color='purple')
plt.plot(th, th, 'k--', label='Ideal Speedup')
plt.xlabel('Number of Threads')
plt.ylabel('Speedup')
plt.title('Threads vs Speedup')
plt.xticks(th)
plt.legend()
plt.savefig('../plots/q2_threads_vs_speedup.png')
plt.close()

# Plot 3: Threads vs Efficiency
plt.figure()
plt.plot(th, efficiencies, marker='o', color='brown')
plt.axhline(y=1.0, color='k', linestyle='--', label='Ideal Efficiency')
plt.xlabel('Number of Threads')
plt.ylabel('Efficiency')
plt.title('Threads vs Efficiency')
plt.xticks(th)
plt.ylim(0, 1.2)
plt.legend()
plt.savefig('../plots/q2_threads_vs_efficiency.png')
plt.close()

print("Q2 Done.")
