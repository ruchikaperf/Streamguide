# Streamguide
An Interactive Guide to Measuring Memory Bandwidth
# STREAM Benchmark on AIX/POWER

**Guide to compiling, running, and testing NUMA-aware memory bandwidth using STREAM on IBM AIX POWER systems.**  
Repo: [GitHub – Streamguide](https://github.com/ruchikaperf/Streamguide/tree/main)

---

## Why STREAM?
STREAM, by Dr. John McCalpin ([source](https://www.cs.virginia.edu/stream/FTP/Code/stream.c)), is the standard for measuring **sustained memory bandwidth**. It tests real DRAM performance (not cache) using four kernels:

| Kernel | Operation | Purpose |
|--------|-----------|---------|
| Copy   | A = B     | Load/store |
| Scale  | A = scalar × B | Load/store + FLOP |
| Add    | A = B + C | Two loads + one store |
| Triad  | A = B + scalar × C | HPC-like workload |

Compare **TRIAD** bandwidth to theoretical peak.

---

## Choosing STREAM_ARRAY_SIZE
Arrays must exceed LLC size to avoid cache effects:  
**Total Bytes = 3 × STREAM_ARRAY_SIZE × 8**

Example:
- L3 cache = 36 MB/socket  
- For 1 socket: N > 1,572,864  
Recommended:
- 4M → ~96 MB  
- 6M → ~144 MB  
- 10M → ~240 MB  

Rule: Use arrays 4–8× LLC for accurate DRAM traffic.

---

## NUMA Awareness (SRAD on AIX)
POWER uses SRADs (NUMA domains):
- Each SRAD = local CPUs + memory  
- Remote access = slower  

Testing per SRAD shows locality performance.

---

## Scripts in Repo
1. **build_and_run_stream.sh**  
   - Compiles STREAM with POWER-optimized GCC flags  
   - Auto-sets array size  
   - Runs baseline test  

2. **numa_srad_test.sh**  
   - Detects SRADs  
   - Runs STREAM per SRAD with CPU/memory binding  
   - Compares local vs remote bandwidth  

3. **numa_tests.sh**  
   - Quick NUMA sensitivity check  
   - Tests local, remote, and full-system runs  

---

## Interpreting Results
Peak BW = Channels × Rate × 8B × Sockets  
Example: POWER10 DDR5 → ~704 GB/s  

Efficiency:
- 70–90% → Excellent  
- 60–70% → Normal  
- <50% → NUMA or affinity issue  

---

## Tuning Tips
- Use GCC with `-Ofast -mcpu=power10 -fopenmp`  
- SMT = 4 or 8  
- Pin threads (`bindprocessor`)  
- Set `MEMORY_AFFINITY=MCM`  
- Disable power-saving  

---

## Troubleshooting
- **Low BW** → SMT off or wrong affinity  
- **Remote faster than local** → Missing pinning  
- **Alloc fail** → Reduce array size or increase paging  

---

## Best Practices
- Arrays ≥ 6M–10M elements  
- Test each SRAD  
- Compare TRIAD vs peak  
- Expect 10–30% drop for remote SRAD  
- STREAM = trusted memory bandwidth benchmark for POWER/AIX  

