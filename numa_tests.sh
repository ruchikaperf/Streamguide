#!/usr/bin/env bash
# NUMA locality tester for AIX/POWER STREAM benchmark

EXE=stream_aix

if [[ ! -f "$EXE" ]]; then
    echo "ERROR: Run build_and_run_stream.sh first!"
    exit 1
fi

CORES=$(lsdev -Cc processor | grep -i available | wc -l)
HALF=$((CORES / 2))

echo ""
echo "==== NUMA LOCAL TEST (MCM affinity enabled) ===="
export OMP_NUM_THREADS=$HALF
export MEMORY_AFFINITY=MCM

bindprocessor -bp 0-$((HALF-1)) ./$EXE

echo ""
echo "==== REMOTE MEMORY TEST (Affinity disabled) ===="
export MEMORY_AFFINITY=DISABLED
bindprocessor -bp 0-$((HALF-1)) ./$EXE

echo ""
echo "==== FULL SYSTEM TEST ===="
export MEMORY_AFFINITY=MCM
export OMP_NUM_THREADS=$CORES
./$EXE
