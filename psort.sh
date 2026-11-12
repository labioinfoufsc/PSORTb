#!/usr/bin/env bash
set -euo pipefail

PSORTB_SCRIPT="${PSORTB_SCRIPT:-/usr/local/psortb/bin/psortb3.pl}"
RESULT_FILE=""
VERBOSE=0
SEQFILE=""
ARGS=()

usage() {
    cat <<USAGE
Usage: $0 [-a|-n|-p] [OPTIONS] -i <sequence file> -r <result file>

Options:
  -i, --seq <file>          Input sequence file (required)
  -f, --format <format>     Sequence format (default: FASTA)
  -d, --divergent <value>   Cutoff for multiple localization flag
  -v, --verbose             Verbose mode
  -c, --cutoff <value>      Cutoff for reported results
  -o, --output <format>     Output format (normal, terse, long)
  -a, --archaea             Archaea
  -n, --negative            Gram negative bacteria
  -p, --positive            Gram positive bacteria
  -e, --exact               Skip SCLBLASTe
  --x-skip-localizations    Skip localizations
  --version                 Show PSORTb version
  -r, --result <file>       Result file output (required)
  -h, --help                Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--seq)
            [[ $# -ge 2 ]] || {
                echo "Error: missing value for $1" >&2
                exit 1
            }
            SEQFILE="$2"
            shift 2
            ;;
        -r|--result)
            [[ $# -ge 2 ]] || {
                echo "Error: missing value for $1" >&2
                exit 1
            }
            RESULT_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=1
            ARGS+=("$1")
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --version)
            "$PSORTB_SCRIPT" --version
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$SEQFILE" || ! -f "$SEQFILE" ]]; then
    echo "Error: input sequence file is required and must exist (-i/--seq)" >&2
    usage >&2
    exit 1
fi

if [[ -z "$RESULT_FILE" ]]; then
    echo "Error: output file must be specified with -r/--result" >&2
    usage >&2
    exit 1
fi

if [[ ! -x "$PSORTB_SCRIPT" ]]; then
    echo "Error: PSORTb executable not found or not executable: $PSORTB_SCRIPT" >&2
    exit 1
fi

# Create output directory
mkdir -p "$(dirname "$RESULT_FILE")"

SEQFILE="$(realpath "$SEQFILE")"
RESULT_DIR="$(cd "$(dirname "$RESULT_FILE")" && pwd)"
RESULT_FILE="$RESULT_DIR/$(basename "$RESULT_FILE")"

# Create temporary directory
TMP_DIR="$(mktemp -d)"
PIDS=()

cleanup() {
    local pid

    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done

    wait 2>/dev/null || true
    rm -rf -- "$TMP_DIR"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Clean FASTA headers
CLEAN_FASTA="$TMP_DIR/clean.fasta"

awk '
    /^>/ {
        sub(/\r$/, "")
        split(substr($0, 2), name, /[ \t]/)
        print ">" name[1]
        next
    }
    {
        sub(/\r$/, "")
        if ($0 != "") print
    }
' "$SEQFILE" > "$CLEAN_FASTA"

# Count sequences
SEQUENCES="$(grep -c '^>' "$CLEAN_FASTA" || true)"

if (( SEQUENCES == 0 )); then
    echo "Error: FASTA contains no sequences" >&2
    exit 1
fi

# Detect available CPUs
CPUS="$(nproc)"
WORKERS="$CPUS"

if (( WORKERS > SEQUENCES )); then
    WORKERS="$SEQUENCES"
fi

printf 'Sequences: %d | Available CPUs: %d | Parallel processes: %d\n' \
    "$SEQUENCES" "$CPUS" "$WORKERS"

if (( VERBOSE )); then
    echo "- Temporary directory: $TMP_DIR"
fi

# Split FASTA into balanced batches
awk -v count="$SEQUENCES" \
    -v workers="$WORKERS" \
    -v dir="$TMP_DIR" '
    /^>/ {
        idx++
        batch = int((idx - 1) * workers / count) + 1
        file = sprintf("%s/batch_%06d.fasta", dir, batch)
    }
    {
        print >> file
    }
' "$CLEAN_FASTA"

# Execute PSORTb batches concurrently
for (( i=1; i<=WORKERS; i++ )); do

    printf -v NUM '%06d' "$i"

    BATCH="$TMP_DIR/batch_${NUM}.fasta"
    PART="$TMP_DIR/result_${NUM}.txt"
    LOG="$TMP_DIR/batch_${NUM}.log"

    echo "[Batch $i/$WORKERS] Starting"

    if (( VERBOSE )); then
        printf '  Command: %q ' \
            "$PSORTB_SCRIPT" "${ARGS[@]}" "$BATCH"
        echo
    fi

    (
        "$PSORTB_SCRIPT" "${ARGS[@]}" "$BATCH" \
            > "$PART" 2> "$LOG"
    ) &

    PIDS+=("$!")
done

# Wait for all PSORTb processes
FAILED=0

for (( i=1; i<=WORKERS; i++ )); do

    printf -v NUM '%06d' "$i"

    if wait "${PIDS[i-1]}"; then

        echo "[Batch $i/$WORKERS] Completed"

        if (( VERBOSE )) && \
           [[ -s "$TMP_DIR/batch_${NUM}.log" ]]; then
            cat "$TMP_DIR/batch_${NUM}.log" >&2
        fi

    else

        echo "[Batch $i/$WORKERS] Failed (PSORTb error)" >&2
        cat "$TMP_DIR/batch_${NUM}.log" >&2
        FAILED=1

    fi
done

PIDS=()

if (( FAILED )); then
    echo "Error: one or more PSORTb batches failed. Final output was not written." >&2
    exit 1
fi

# Merge results in batch order
MERGED="$TMP_DIR/merged.txt"
: > "$MERGED"

for (( i=1; i<=WORKERS; i++ )); do

    printf -v NUM '%06d' "$i"
    PART="$TMP_DIR/result_${NUM}.txt"

    if (( i == 1 )); then
        # Keep the header from the first batch
        cat "$PART" >> "$MERGED"
    else
        # Skip the header from subsequent batches
        tail -n +2 "$PART" >> "$MERGED"
    fi

done

# Save final output
cp -- "$MERGED" "$RESULT_FILE"

echo "Final output: $RESULT_FILE"
