#!/usr/bin/env bash
# NUMA SRAD locality tester for AIX/POWER STREAM benchmark
# Runs STREAM on each SRAD that has CPU + memory assigned.

EXE=stream_aix

if [[ ! -f "$EXE" ]]; then
    echo "ERROR: Run build_and_run_stream.sh first!"
    exit 1
fi

echo "Detecting valid SRADs with active CPU + memory…"

# Detect SRADs with non-zero MEM and valid CPU list
SRADS=$(
  lssrad -av | awk '
    /^[[:space:]]*[0-9]+[[:space:]]*$/ {
      # This line contains only an SRAD number
      srad = $0
      gsub(/^[ \t]+|[ \t]+$/, "", srad)

      # Read the next line (detail row)
      if (getline > 0) {
        n = split($0, a)
        mem = (n >= 2 ? a[2] : "")
        cpu = (n >= 3 ? a[3] : "")

        # Clean whitespace
        gsub(/^[ \t]+|[ \t]+$/, "", mem)
        gsub(/^[ \t]+|[ \t]+$/, "", cpu)

        # Keep only SRADs with memory > 0 and a CPU list
        if (mem != "" && cpu != "" && (mem + 0) > 0)
          print srad
      }
    }
  ' | sort -n | uniq
)

if [[ -z "$SRADS" ]]; then
    echo "ERROR: No valid NUMA SRADs found."
    exit 1
fi

echo "Valid SRADs detected: $SRADS"
echo ""

echo "==== STARTING NUMA TESTS ===="

for S in $SRADS; do
    echo ""
    echo "==============================="
    echo " Running STREAM on SRAD $S"
    echo "==============================="

    # Extract CPU list for this SRAD
    CPU_LIST=$(lssrad -av | awk -v srad="$S" '
      /^[[:space:]]*[0-9]+[[:space:]]*$/ {
        id = $0
        gsub(/^[ \t]+|[ \t]+$/, "", id)
        if (id == srad && getline > 0) {
          split($0, a)
          cpu=a[3]
          gsub(/^[ \t]+|[ \t]+$/, "", cpu)
          print cpu
        }
      }
    ')

    echo "SRAD $S CPU list: $CPU_LIST"

    export MEMORY_AFFINITY=MCM
    export OMP_NUM_THREADS=$(echo "$CPU_LIST" | awk -F- '{print $2-$1+1}')

    echo "OMP_NUM_THREADS=$OMP_NUM_THREADS"

    # Bind STREAM to this SRAD CPU list
    echo "Executing: bindprocessor -bp $CPU_LIST $EXE"
    bindprocessor -bp "$CPU_LIST" ./$EXE
done

echo ""
echo "==== FULL SYSTEM TEST ===="
export MEMORY_AFFINITY=MCM
export OMP_NUM_THREADS=$(lsdev -Cc processor | grep -i available | wc -l)

./$EXE
