#!/usr/bin/env bash
# run.sh - compile (if needed) and run the riscv_cpu testbench against a
# chosen program file, without having to retype iverilog/vvp by hand.
#
# Usage:
#   ./scripts/run.sh                              # runs programs/default.txt, 100 cycles
#   ./scripts/run.sh programs/sample1.txt          # runs a specific program, 100 cycles
#   ./scripts/run.sh programs/sample1.txt 60       # ...for 60 cycles
#   ./scripts/run.sh programs/sample1.txt 60 -f    # force a clean recompile first
#
# Waveform is written to waves/riscv_cpu_tb.vcd (open with: gtkwave waves/riscv_cpu_tb.vcd)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRAM="${1:-$ROOT/programs/default.txt}"
CYCLES="${2:-100}"
FORCE="${3:-}"

# allow bare filenames like "sample1.txt" too
if [[ ! -f "$PROGRAM" && -f "$ROOT/programs/$PROGRAM" ]]; then
    PROGRAM="$ROOT/programs/$PROGRAM"
fi

if [[ ! -f "$PROGRAM" ]]; then
    echo "error: program file not found: $PROGRAM" >&2
    exit 1
fi

mkdir -p "$ROOT/waves" "$ROOT/build" "$ROOT/regdumps"

SIM="$ROOT/build/sim.out"

if [[ "$FORCE" == "-f" || ! -f "$SIM" ]]; then
    echo "[run.sh] compiling..."
    # Globbing rtl/*.v picks up controller.v, datapath.v, and any other
    # submodules (alu.v, regfile.v, hazard_unit.v, etc.) you already have
    # in rtl/ alongside riscv_cpu.v / riscv_cpu_wrapper.v.
    iverilog -g2012 -o "$SIM" \
        "$ROOT"/rtl/*.v \
        "$ROOT"/tb/instr_mem.v \
        "$ROOT"/tb/data_mem.v \
        "$ROOT"/tb/riscv_cpu_tb.v
fi

# name of the program, used to name the register-dump files and to look
# up an optional programs/<name>.expect self-check file
name="$(basename "$PROGRAM" .txt)"
REGDUMP="$ROOT/regdumps/$name"

PLUSARGS=(+MEMFILE="$PROGRAM" +CYCLES="$CYCLES" +REGDUMP="$REGDUMP")
EXPECT_FILE="$ROOT/programs/$name.expect"
if [[ -f "$EXPECT_FILE" ]]; then
    PLUSARGS+=(+EXPECT="$EXPECT_FILE")
fi

echo "[run.sh] running: $PROGRAM  (cycles=$CYCLES)"
(cd "$ROOT" && vvp "$SIM" "${PLUSARGS[@]}")

echo "[run.sh] done. waveform: $ROOT/waves/riscv_cpu_tb.vcd"
echo "[run.sh] register dump: $REGDUMP.txt (human-readable) / $REGDUMP.hex (memory-image, readmemh format)"
