#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MEM_BYTES=16384
PICOLIBC_SPECS="${PICOLIBC_SPECS:-/usr/lib/picolibc/riscv64-unknown-elf/picolibc.specs}"
CC="${RISCV_CC:-riscv64-unknown-elf-gcc}"
OBJCOPY="${RISCV_OBJCOPY:-riscv64-unknown-elf-objcopy}"
OBJDUMP="${RISCV_OBJDUMP:-riscv64-unknown-elf-objdump}"
RISCV_MARCH="${RISCV_MARCH:-rv64im}"
RISCV_MABI="${RISCV_MABI:-lp64}"

if [[ $# -ne 1 ]]; then
    echo "Usage: bash run_c.sh <program-folder-or-C-file>" >&2
    exit 2
fi

INPUT="$1"
if [[ ! -e "$INPUT" && -e "$ROOT/$INPUT" ]]; then INPUT="$ROOT/$INPUT"; fi
if [[ -d "$INPUT" ]]; then
    PROGRAM_DIR="$(cd -- "$INPUT" && pwd)"
    if [[ -f "$PROGRAM_DIR/main.c" ]]; then SOURCE="$PROGRAM_DIR/main.c"
    else
        shopt -s nullglob
        C_FILES=("$PROGRAM_DIR"/*.c)
        if [[ ${#C_FILES[@]} -ne 1 ]]; then
            echo "Put one main.c in the folder, or pass the C file directly." >&2
            exit 2
        fi
        SOURCE="${C_FILES[0]}"
    fi
elif [[ -f "$INPUT" && "$INPUT" == *.c ]]; then
    SOURCE="$(cd -- "$(dirname -- "$INPUT")" && pwd)/$(basename -- "$INPUT")"
    PROGRAM_DIR="$(dirname -- "$SOURCE")"
else
    echo "Program folder or C source not found: $INPUT" >&2
    exit 2
fi

if ! command -v "$CC" >/dev/null 2>&1; then echo "Missing RISC-V compiler: $CC" >&2; exit 1; fi
if ! command -v "$OBJCOPY" >/dev/null 2>&1; then echo "Missing RISC-V objcopy: $OBJCOPY" >&2; exit 1; fi
if [[ ! -f "$PICOLIBC_SPECS" ]]; then
    echo "Picolibc specs not found: $PICOLIBC_SPECS" >&2
    echo "Set PICOLIBC_SPECS to its installed path." >&2
    exit 1
fi

BUILD_DIR="$PROGRAM_DIR/build"
mkdir -p "$BUILD_DIR"
ELF="$BUILD_DIR/program.elf"
BIN="$BUILD_DIR/program.bin"
USER_OBJECT="$BUILD_DIR/user.o"
WRAPPER_OBJECT="$BUILD_DIR/sim_main.o"
WRAPPER_SOURCE="$BUILD_DIR/sim_main.c"

# Keep Picolibc's normal startup and semihosting. Rename the user's main,
# then let a wrapper call it and issue EBREAK when it returns.
cat > "$WRAPPER_SOURCE" <<'WRAPPER_C'
int brisc_user_main(void);

int main(void) {
    int status = brisc_user_main();
    __asm__ volatile ("li a0, 0\n\tebreak" ::: "a0", "memory");
    return status;
}
WRAPPER_C

COMMON_FLAGS=(-march="$RISCV_MARCH" -mabi="$RISCV_MABI" -mcmodel=medany --specs="$PICOLIBC_SPECS" --oslib=semihost)
"$CC" "${COMMON_FLAGS[@]}" -Dmain=brisc_user_main -c "$SOURCE" -o "$USER_OBJECT"
"$CC" "${COMMON_FLAGS[@]}" -c "$WRAPPER_SOURCE" -o "$WRAPPER_OBJECT"
"$CC" "${COMMON_FLAGS[@]}" "$USER_OBJECT" "$WRAPPER_OBJECT" -o "$ELF"

if command -v "$OBJDUMP" >/dev/null 2>&1; then
    "$OBJDUMP" -d "$ELF" > "$BUILD_DIR/program.disasm"
fi
"$OBJCOPY" -O binary "$ELF" "$BIN"

python3 - "$BIN" "$BUILD_DIR" "$MEM_BYTES" <<'PY'
from pathlib import Path
import sys

image_path, build_path, limit = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])
image = image_path.read_bytes()
if len(image) > limit:
    raise SystemExit(f"Program image is {len(image)} bytes; data RAM holds {limit} bytes.")

# Instruction BRAM: one little-endian 32-bit instruction per readmemh line.
padded = image + bytes((-len(image)) % 4)
words = [f"{int.from_bytes(padded[i:i+4], 'little'):08x}" for i in range(0, len(padded), 4)]
if len(words) > 16384:
    raise SystemExit("Program exceeds the 16,384-word instruction RAM.")
words.extend(["00000013"] * (16384 - len(words)))
(build_path / "main_bsram.mem").write_text("\n".join(words) + "\n")

# Data BRAM: packed little-endian 64-bit words, mirrored for semihost strings.
data = image.ljust(limit, b"\0")
data_words = [f"{int.from_bytes(data[i:i+8], 'little'):016x}" for i in range(0, limit, 8)]
(build_path / "zeros2048.dat").write_text("\n".join(data_words) + "\n")
PY

cp -- "$BUILD_DIR/main_bsram.mem" "$ROOT/main_bsram.mem"
cp -- "$BUILD_DIR/zeros2048.dat" "$ROOT/data/zeros2048.dat"
echo "Built $ELF"
echo "Running simulation ($RISCV_MARCH, Picolibc semihosting, PC 0x80000000)..."
cd "$ROOT"
bash ./run_sim64 +prog_address=80000000
