#!/usr/bin/env bash
#
# build_and_run_stream.sh
#
# STREAM Benchmark Helper Script for AIX/POWER
#
# Features:
#   ✓ POWER-optimized GNU compiler flags
#   ✓ Auto-detect STREAM array size based on memory
#   ✓ Auto thread detection ("auto")
#   ✓ Runs baseline test
#   ✓ Outputs clean formatted logs
#
# GitHub Repo:
#   https://github.com/ruchikaperf/Streamguide/tree/main
#
# Usage:
#   ./build_and_run_stream.sh [theoretical_gbps] [threads] [runs] [output_file]
#
# Examples:
#   ./build_and_run_stream.sh 409 64 3 stream_out.txt
#   ./build_and_run_stream.sh          # defaults: 409 GB/s, auto threads, 3 runs
#

set -euo pipefail

# --- Defaults ---
THEORETICAL_GBPS="${1:-409}"
THREADS="${2:-auto}"
RUNS="${3:-3}"
OUTFILE="${4:-stream_out.txt}"

SRC="stream.c"
BIN="./stream_aix_gnu"

##############################
# 1. Compiler Selection
##############################
if command -v gcc >/dev/null 2>&1; then
    CC=gcc
elif command -v /opt/freeware/bin/gcc >/dev/null 2>&1; then
    CC=/opt/freeware/bin/gcc
else
    echo "ERROR: gcc not found! Install GCC from AIX Toolbox."
    exit 2
fi
echo "Using compiler: $CC"

##############################
# 2. Auto-SELECT ARRAY SIZE
##############################
# RULE:
#   Use ~70% of available memory for STREAM (A very safe large array)
#   ARRAY_SIZE = (available_mem_GB * 0.70 * 1024^3) / 8
#
get_avail_mem_gb() {
    # Works on AIX
    if command -v svmon >/dev/null 2>&1; then
        FREE_MB=$(svmon -G | awk '/memory/ {print $3}')
        echo $((FREE_MB / 1024))
    else
        echo 4  # fallback
    fi
}

AVAIL_MEM_GB=$(get_avail_mem_gb)
ARRAY_BYTES=$(echo "$AVAIL_MEM_GB * 0.70 * 1024 * 1024 * 1024" | bc)
ARRAY_SIZE=$(echo "$ARRAY_BYTES / 8" | bc)

echo "Auto-calculated ARRAY_SIZE = $ARRAY_SIZE (elements)"
export STREAM_ARRAY_SIZE="$ARRAY_SIZE"

##############################
# 3. POWER-Optimized GCC Flags
##############################
CFLAGS="-O3 -mcpu=power10 -mtune=power10 -funroll-loops -fopenmp -fno-tree-vectorize -pipe"
LDFLAGS="-fopenmp -pthread -lm"

if [ ! -f "$SRC" ]; then
    echo "ERROR: $SRC not found in $(pwd)"
    exit 1
fi

echo "Building STREAM..."
$CC $CFLAGS -o "$BIN" "$SRC" $LDFLAGS || {
    echo "Build failed. Try removing -mcpu=power10 or -funroll-loops."
    exit 3
}

##############################
# 4. Thread Auto-Detection
##############################
if [ "$THREADS" = "auto" ]; then
    if command -v lsdev >/dev/null 2>&1; then
        THREADS=$(lsdev -Cc processor | grep -i available | wc -l)
    elif command -v nproc >/dev/null 2>&1; then
        THREADS=$(nproc)
    else
        THREADS=1
    fi
fi

echo "Using $THREADS threads"
export OMP_NUM_THREADS="$THREADS"

##############################
# 5. Logging
##############################
echo "STREAM Benchmark Run: $(date)" > "$OUTFILE"
echo "Theoretical_GBps=$THEORETICAL_GBPS" >> "$OUTFILE"
echo "Threads=$THREADS" >> "$OUTFILE"
echo "Runs=$RUNS" >> "$OUTFILE"
echo "ArraySize=$ARRAY_SIZE" >> "$OUTFILE"
echo "----------------------------------" >> "$OUTFILE"

##############################
# 6. Optional CPU Pinning
##############################

# Optional CPU pinning:
# Example usage:
#   BIND_CMD="bindprocessor $BIN 0" ./build_and_run_stream.sh
#   BIND_CMD="bindprocessor -c 0,1,2,3" ./build_and_run_stream.sh
#
# User is responsible for specifying valid CPU indices.

if [ -n "${BIND_CMD:-}" ]; then
    echo "Using CPU binding: $BIND_CMD"
    echo "BIND_CMD=$BIND_CMD" >> "$OUTFILE"
    eval "$BIND_CMD" || echo "Warning: bindprocessor failed"
fi

##############################
# 7. Run STREAM (Baseline + main)
##############################
set +e

echo "Running baseline warmup..."
"$BIN" >/dev/null 2>&1

echo "Running STREAM benchmark..."
"$BIN" | tee -a "$OUTFILE"
RET=$?

set -e
if [ $RET -ne 0 ]; then
    echo "STREAM exited with non-zero exit code $RET"
    exit $RET
fi

echo "Benchmark complete. Output saved to $OUTFILE"
