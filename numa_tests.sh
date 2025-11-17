#!/usr/bin/env bash
# NUMA locality tester for AIX/POWER STREAM benchmark
# Compares:
#   1) Local MCM memory
#   2) Remote (disabled affinity)
#   3) Full system bandwidth

EXE=stream_aix

if [[ ! -f "$EXE" ]]; then
    echo "ERROR: STREAM binary '$EXE' not found!"
    echo "Run:  ./build_and_run_stream.sh"
    exit 1
fi

# Total physical cores (not SMT threads)
CORES=$(lsdev -Cc processor | grep -i available | wc -l)
HALF=$((CORES / 2))
RANGE="0-$((HALF-1))"

echo "Detected $CORES physical processors"
echo "Using $HALF cores for NUMA locality tests"
echo "CPU range: $RANGE"
echo ""

###############################################################################
echo "==== [1] LOCAL NUMA TEST (MCM affinity ON) ===="
###############################################################################
export OMP_NUM_THREADS=$HALF
export MEMORY_AFFINITY=MCM

echo "Running STREAM with:"
echo "  OMP_NUM_THREADS=$OMP_NUM_THREADS"
echo "  MEMORY_AFFINITY=MCM"
echo "  CPUs bound: $RANGE"
echo ""

bindprocessor -bp $RANGE $PWD/$EXE | tee local_numa.txt


###############################################################################
echo ""
echo "==== [2] REMOTE MEMORY TEST (Affinity DISABLED) ===="
###############################################################################
export MEMORY_AFFINITY=DISABLED
export OMP_NUM_THREADS=$HALF

echo "Running STREAM with:"
echo "  MEMORY_AFFINITY=DISABLED"
echo "  CPUs bound: $RANGE"
echo ""

bindprocessor -bp $RANGE $PWD/$EXE | tee remote_numa.txt


###############################################################################
echo ""
echo "==== [3] FULL SYSTEM TEST (all cores) ===="
###############################################################################
export MEMORY_AFFINITY=MCM
export OMP_NUM_THREADS=$CORES

echo "Running STREAM with:"
echo "  MEMORY_AFFINITY=MCM"
echo "  OMP_NUM_THREADS=$CORES"
echo ""

./$EXE | tee full_system.txt

echo ""
echo "Completed. Output files:"
echo "  - local_numa.txt"
echo "  - remote_numa.txt"
echo "  - full_system.txt"
