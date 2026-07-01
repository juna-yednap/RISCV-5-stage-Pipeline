#!/usr/bin/env bash
# run_all.sh - compile once, then run every .txt program in programs/
# one by one, saving each run's console output and waveform separately.
#
# Usage:
#   ./scripts/run_all.sh              # 100 cycles per program
#   ./scripts/run_all.sh 200          # 200 cycles per program

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CYCLES="${1:-100}"
SIM="$ROOT/build/sim.out"

mkdir -p "$ROOT/build" "$ROOT/waves" "$ROOT/logs" "$ROOT/regdumps"

echo "[run_all.sh] compiling..."
iverilog -g2012 -o "$SIM" \
    "$ROOT"/rtl/*.v \
    "$ROOT"/tb/instr_mem.v \
    "$ROOT"/tb/data_mem.v \
    "$ROOT"/tb/riscv_cpu_tb.v

shopt -s nullglob
programs=("$ROOT"/programs/*.txt)
shopt -u nullglob

if [[ ${#programs[@]} -eq 0 ]]; then
    echo "no .txt programs found in $ROOT/programs"
    exit 1
fi

declare -a summary

for prog in "${programs[@]}"; do
    name="$(basename "$prog" .txt)"
    echo ""
    echo "==================================================================="
    echo " running: $name  (cycles=$CYCLES)"
    echo "==================================================================="

    REGDUMP="$ROOT/regdumps/$name"
    PLUSARGS=(+MEMFILE="$prog" +CYCLES="$CYCLES" +REGDUMP="$REGDUMP")
    EXPECT_FILE="$ROOT/programs/$name.expect"
    has_expect=0
    if [[ -f "$EXPECT_FILE" ]]; then
        PLUSARGS+=(+EXPECT="$EXPECT_FILE")
        has_expect=1
    fi

    (cd "$ROOT" && vvp "$SIM" "${PLUSARGS[@]}") \
        | tee "$ROOT/logs/$name.log"

    # keep each program's waveform instead of overwriting one shared file
    if [[ -f "$ROOT/waves/riscv_cpu_tb.vcd" ]]; then
        mv "$ROOT/waves/riscv_cpu_tb.vcd" "$ROOT/waves/$name.vcd"
    fi

    if [[ "$has_expect" -eq 1 ]]; then
        if grep -q "RESULT: ALL .* PASSED" "$ROOT/logs/$name.log"; then
            summary+=("PASS  $name")
        else
            summary+=("FAIL  $name")
        fi
    else
        summary+=("--    $name (no .expect file, not checked)")
    fi
done

echo ""
echo "[run_all.sh] done. logs in logs/, waveforms in waves/*.vcd, register dumps in regdumps/*.txt|.hex"
echo ""
echo "==================================================================="
echo " summary"
echo "==================================================================="
for line in "${summary[@]}"; do
    echo " $line"
done
