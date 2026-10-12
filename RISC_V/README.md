# BRISC-V RV64IM Core

A Verilog implementation of a 64-bit RISC-V integer processor with a seven-stage pipeline, stall/bypass control, instruction and data memories, and a simple Icarus Verilog simulation flow. The C runner builds a program for the core, creates the memory images, and starts the simulation.

## Core features

- 64-bit integer datapath, register values, and architectural address signals; 32-bit instructions.
- RV64I-style integer operations and RV64M multiply/divide operations in the ALU: `MUL`, `MULH`, `MULHSU`, `MULHU`, `DIV`, `DIVU`, `REM`, `REMU`, `MULW`, `DIVW`, `DIVUW`, `REMW`, and `REMUW`.
- Seven-stage pipeline with stall and bypass logic.
- 32 integer registers (`x0` through `x31`); `x0` remains zero.
- Separate instruction and data RAMs.
- Byte, halfword, word, and doubleword loads/stores with signed/unsigned load handling.
- Picolibc semihosting output for C programs, including `printf` through `SYS_WRITEC`.

This repository contains the implemented RTL and simulation setup; it is not a complete RISC-V system or a claim of support for every optional RISC-V extension.

## Repository layout

```text
src_64/       RV64IM core and memory RTL
tb/           Icarus Verilog testbench
 llvm/        Sample C programs and their generated build folders
 data/        Initial data-memory image
 results/     Register and data-memory dumps from simulation
 run_c.sh     Compile a C program, prepare memory images, and simulate
 run_sim64    Compile the RTL testbench and run the simulator
 main_bsram.mem Default/generated instruction-memory image
```

## Requirements

Run from Linux or WSL with these tools installed and on `PATH`:

- Icarus Verilog: `iverilog` and `vvp`
- RISC-V bare-metal GCC: `riscv64-unknown-elf-gcc`
- RISC-V binutils: `riscv64-unknown-elf-objcopy`; `riscv64-unknown-elf-objdump` is used when available
- Python 3
- Picolibc for `riscv64-unknown-elf`, including its semihosting specs file

By default, `run_c.sh` looks for Picolibc here:

```text
/usr/lib/picolibc/riscv64-unknown-elf/picolibc.specs
```

If it is installed elsewhere, set `PICOLIBC_SPECS` when running the script:

```bash
PICOLIBC_SPECS=/path/to/picolibc.specs bash run_c.sh llvm/hello
```

The compiler, objcopy, and objdump commands can also be overridden with `RISCV_CC`, `RISCV_OBJCOPY`, and `RISCV_OBJDUMP`. The default compiler target is `rv64im` with the `lp64` ABI.

## Build and run a C program

From the root of this repository:

```bash
bash run_c.sh llvm/hello
```

Pass either a program directory or a `.c` file. A directory should contain `main.c`, or exactly one `.c` source file. For example:

```bash
bash run_c.sh llvm/memory
bash run_c.sh llvm/mul
bash run_c.sh llvm/hello/hello.c
```

To add a program, create a folder under `llvm/` and put one C source file in it. For example, `llvm/my_program/main.c` can be run with:

```bash
bash run_c.sh llvm/my_program
```

The runner compiles with `-march=rv64im -mabi=lp64 -mcmodel=medany`, Picolibc, and semihosting. It creates these files under the program's `build/` folder:

- `program.elf`
- `program.disasm` when objdump is available
- `program.bin`
- `main_bsram.mem` and `zeros2048.dat`

It copies the generated memory images to the project root (replacing the root images from the previous run) and starts the simulator at `0x80000000`. The script currently rejects a binary image larger than 16 KiB.

The runner adds a small wrapper around the user's `main()`. When `main()` returns, that wrapper issues the EBREAK convention used by the testbench to stop simulation. The user C source does not need to add assembly for this termination behavior.

## Run the simulator directly

If you have already prepared the memory images, run:

```bash
bash run_sim64 +prog_address=80000000
```

The testbench prints register writeback activity and semihosted characters. On EBREAK it stops and writes register and data-memory dumps to `results/registers.txt` and `results/data_memory.txt`.

## Memory configuration

The default RTL parameters configure:

- Instruction RAM: 16,384 x 32-bit words (64 KiB).
- Data RAM: 2,048 x 64-bit words (16 KiB total), byte-addressed with eight byte lanes per word.

The architectural address signals are 64 bits, but data RAM selection uses the low 14 address bits. This gives a 16 KiB local data-memory window; addresses that differ by 16 KiB alias to the same RAM location. Keep the program's data, stack, and arrays within this window.

## RTL map

- `RISC_V_Core.v`: top-level core and pipeline connections.
- `fetch.v`, `decode.v`, `execute.v`, `memory.v`, `writeback.v`: main pipeline units.
- `fetch_pipe.v`, `decode_pipe.v`, `execute_pipe.v`, `memory_pipe.v`: pipeline registers.
- `control_unit.v`, `stallControl.v`, `ALU.v`: instruction control, hazard handling, and arithmetic/logic operations.
- `bsram.v`, `bram.v`, `i_mem_interface.v`, `d_mem_interface.v`, `memory_hierarchy.v`: instruction/data memories and interfaces.
- `semihost_putchar.v`: semihosted character output.
- `tb/tb_RISC_V_Core.v`: simulation testbench.

## Notes

- `llvm/mul` contains a C test harness that uses inline assembly to explicitly exercise individual RV64M instructions.
- The testbench writes results into `results/`; each simulation run overwrites those dumps.
- The RTL uses Verilog division and remainder operators. Corner cases such as division by zero should be verified with dedicated tests before relying on them.

