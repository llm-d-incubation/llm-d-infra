#!/usr/bin/env bash
set -euo pipefail

# On SIGINT (Ctrl‑C), print a message and exit with 130
trap 'echo "⏹  Aborted by user (SIGINT)"; exit 130' SIGINT

# Run N waves of $X concurrent requests
run_benchmark() {
  local N=$1       # Number of waves
  local in_len=$2  # Input length (fixed)
  local out_len=$3 # Output length (fixed)

  local N_X=$(( N * X ))
  local outfile="${outdir}/${X}_${N_X}_${in_len}_${out_len}.log"
  just benchmark "$X" "$N_X" "$in_len" "$out_len" |& tee "$outfile"
}

# create out dir
outdir="/app/results/$(cat ./TIMESTAMP)"

# reproducibility
mkdir -p "${outdir}/repro"
cp "/app/NAME" "${outdir}/NAME"
cat "$0" > ${outdir}/repro/run.sh # 
cp "/app/values.yaml" "${outdir}/repro/values.yaml"


# Sweep it
for (( X=256; X<=32768; X*=2 )); do
  run_benchmark 2 128 2048
done
