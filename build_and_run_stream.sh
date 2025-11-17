#!/usr/bin/env bash
#
# build_and_run_stream.sh
# Compile stream.c with GNU on AIX, then run the binary.
#
# Usage:
#   ./build_and_run_stream.sh [theoretical_gbps] [threads] [runs] [output_file]
# Examples:
#   ./build_and_run_stream.sh 409 64 3 stream_out.txt
#   ./build_and_run_stream.sh       # uses defaults: theoretical=409, threads=all, runs=3
#
set -euo pipefail

# --- Defaults ---
THEORETICAL_GBPS="${1:-409}"   # user-specified theoretical peak in GB/s
THREADS="${2:-auto}"           # "auto" or a number
RUNS="${3:-3}"
OUTFILE="${4:-stream_out.txt}"

SRC="stream.c"
BIN="./stream_aix_gnu"

# Compiler selection - try common GNU names
if command -v gcc >/dev/null 2>&1; then
  CC=gcc
elif command -v /opt/freeware/bin/gcc >/dev/null 2>&1; then
  CC=/opt/freeware/bin/gcc
else
  echo "ERROR: gcc not found in PATH. Install GNU gcc and retry."
  exit 2
fi

echo "Using compiler: $CC"
echo "Building $SRC -> $BIN"

# Common flags for AIX + GNU; adjust as needed
CFLAGS="-O3 -funroll-loops -fopenmp -march=native -pipe"
LDFLAGS="-fopenmp -lm -pthread"

# If file not found, exit
if [ ! -f "$SRC" ]; then
  echo "ERROR: $SRC not found in $(pwd). Place stream.c here."
  exit 1
fi

$CC $CFLAGS -o "$BIN" "$SRC" $LDFLAGS || {
  echo "Build failed. Try removing -march=native or -funroll-loops on AIX."
  exit 3
}

# Determine number of hardware threads (AIX / generic fallback)
if [ "$THREADS" = "auto" ]; then
  # Try nproc, if available; else fallback to 1
  if command -v nproc >/dev/null 2>&1; then
    THREADS=$(nproc)
  else
    # On AIX: use lsdev or lparstat? fallback to 1
    THREADS=1
  fi
fi

echo "Running STREAM: threads=${THREADS}, runs=${RUNS}"
echo "Theoretical peak: ${THEORETICAL_GBPS} GB/s"
echo "" > "$OUTFILE"
echo "STREAM run: $(date)" >> "$OUTFILE"
echo "Theoretical_GBps,Threads,Runs: ${THEORETICAL_GBPS},${THREADS},${RUNS}" >> "$OUTFILE"
echo "---- STREAM OUTPUT ----" >> "$OUTFILE"

# Run the binary with OMP_NUM_THREADS set; capture stdout/stderr
export OMP_NUM_THREADS="$THREADS"

# Helpful: allow user to pin CPUs manually or via bindprocessor (AIX)
# If user wants to pin, they can set BIND_CMD env var, e.g.:
# BIND_CMD="bindprocessor -c 0,1,2,3" ./build_and_run_stream.sh
if [ -n "${BIND_CMD:-}" ]; then
  echo "Using user-specified BIND_CMD: $BIND_CMD"
  echo "Running bind -> stream"
  eval "$BIND_CMD" &
  # note: user should ensure binding command is correct for AIX
fi

# Run and append output
# Many STREAM variants accept optional arguments; run with no args.
set +e
"$BIN" 2>&1 | tee -a "$OUTFILE"
RET=$?
set -e
if [ $RET -ne 0 ]; then
  echo "STREAM binary exited with $RET (non-zero). See $OUTFILE"
  exit $RET
fi

echo "STREAM output saved to $OUTFILE"
