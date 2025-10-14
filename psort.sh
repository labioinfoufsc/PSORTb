#!/usr/bin/env bash
set -e

PSORTB_SCRIPT="/usr/local/psortb/bin/psortb3.pl"
RESULT_FILE=""
VERBOSE=0

usage() {
    echo "Usage: $0 [-a|-n|-p] [OPTIONS] -i <sequence file> -r <result file>"
    echo ""
    echo "Options:"
    echo "  -i, --seq <file>          Input sequence file (required)"
    echo "  -f, --format <format>     Sequence format (default: FASTA)"
    echo "  -d, --divergent <value>   Cutoff for multiple localization flag"
    echo "  -v, --verbose             Verbose mode"
    echo "  -c, --cutoff <value>      Cutoff for reported results"
    echo "  -o, --output <format>     Output format (normal, terse, long)"
    echo "  -a, --archaea             Archaea"
    echo "  -n, --negative            Gram negative bacteria"
    echo "  -p, --positive            Gram positive bacteria"
    echo "  -e, --exact               Skip SCLBLASTe"
    echo "  --x-skip-localizations    Skip localizations"
    echo "  --version                 Show PSORTb version"
    echo "  -r, --result <file>       Result file output (required)"
    echo "  -h, --help                Show this help message"
    exit 0
}

# Parse args
ARGS=()
SEQFILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--seq)
            SEQFILE="$2"
            shift 2
            ;;
        -r|--result)
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

# Check required inputs
if [[ -z "$SEQFILE" ]]; then
    echo "Error: input sequence file is required (-i/--seq)"
    usage
fi

if [[ ! -f "$SEQFILE" ]]; then
    echo "Error: file '$SEQFILE' does not exist"
    exit 1
fi

if [[ -z "$RESULT_FILE" ]]; then
    echo "Error: output file must be specified with -r/--result"
    usage
fi

# Create directory for output if it doesn't exist
mkdir -p "$(dirname "$RESULT_FILE")"

# Create temporary "clean" FASTA file
CLEAN_FASTA="$(mktemp --suffix=.clean.fasta)"
if [[ $VERBOSE -eq 1 ]]; then
    echo "- Creating temporary clean FASTA: $CLEAN_FASTA"
fi

awk 'BEGIN{RS=">";ORS=""}NR>1{n=split($0,a,"\n");split(a[1],b,/[ \t]/);print ">"b[1]"\n";for(i=2;i<=n;i++){if(a[i]!="")print a[i]"\n"}}' $SEQFILE > $CLEAN_FASTA


echo "Saving results to $RESULT_FILE"

# Run PSORTb
CMD="$PSORTB_SCRIPT ${ARGS[*]} $CLEAN_FASTA > $RESULT_FILE"
[[ $VERBOSE -eq 1 ]] && echo "- Running: $CMD"
eval "$CMD"

# Remove temporary file
rm -f "$CLEAN_FASTA"
[[ $VERBOSE -eq 1 ]] && echo "- Temporary clean FASTA removed"

