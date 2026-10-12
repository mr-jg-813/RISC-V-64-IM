# GRISC-V RV64IM Core

A 64-bit RISC-V processor implemented in Verilog. This project contains the core RTL, a seven-stage pipeline, instruction and data memories, and an Icarus Verilog simulation flow. A helper script compiles C programs, prepares the memory images, and runs the simulation.

## Features

- 64-bit datapath and architectural address signals with 32-bit instructions.
- Seven-stage pipeline with stall and bypass control.
- 32 integer registers (`x0`–`x31`); `x0` is hardwired to zero.
- RV64I-style integer operations and selected RV64M multiply/divide operations.
- Separate instruction and data RAMs.
- Byte, halfword, word, and doubleword loads and stores, with signed and unsigned loads.
- Picolibc semihosting for program output, including `printf` via `SYS_WRITEC`.

This repository provides the implemented RTL and simulation setup. It does not claim support for every RISC-V instruction or optional extension.

## Quick start

From the repository root in Linux or WSL, build and run one of the sample programs:

```bash
bash run_c.sh llvm/hello
```

Other examples:

```bash
bash run_c.sh llvm/memory
bash run_c.sh llvm/mul
bash run_c.sh llvm/hello/hello.c
```

The argument can be a program folder or a `.c` file. A folder must contain `main.c`, or exactly one `.c` file.

## Requirements

Install these tools and make them available on `PATH`:

- Icarus Verilog (`iverilog` and `vvp`)
- RISC-V bare-metal GCC (`riscv64-unknown-elf-gcc`)
- RISC-V binutils (`riscv64-unknown-elf-objcopy`; `riscv64-unknown-elf-objdump` is optional)
- Python 3
- Picolibc for `riscv64-unknown-elf`, including its semihosting specs file

By default, the runner expects Picolibc specs at:

```text
/usr/lib/picolibc/riscv64-unknown-elf/picolibc.specs
```

If your file is elsewhere, set `PICOLIBC_SPECS`:

```bash
PICOLIBC_SPECS=/path/to/picolibc.specs bash run_c.sh llvm/hello
```

You can also override the tool names with `RISCV_CC`, `RISCV_OBJCOPY`, and `RISCV_OBJDUMP`. The default compiler flags target `rv64im` with the `lp64` ABI.

## Add a C program

Create a folder under `llvm/` and add a `main.c` file. For example:

```text
llvm/
└── my_program/
    └── main.c
```

Then run:

```bash
bash run_c.sh llvm/my_program
```

The runner compiles the program with `-march=rv64im -mabi=lp64 -mcmodel=medany`, Picolibc, and semihosting. It adds a wrapper that stops simulation with the testbench's EBREAK convention when `main()` returns; C source code does not need to add assembly for this.

Each program's `build/` folder receives:

- `program.elf` — linked RISC-V executable
- `program.bin` — raw program image
- `program.disasm` — disassembly, when `objdump` is available
- `main_bsram.mem` and `zeros2048.dat` — instruction and data memory images

The generated images are copied into the project before simulation. The runner refuses programs larger than the 16 KiB data-memory limit. A later run replaces the root memory images with the new program's images.

## Run the simulator directly

After memory images have been prepared, run:

```bash
bash run_sim64 +prog_address=80000000
```

The testbench prints register writeback activity and semihosted characters. On EBREAK, it stops and writes simulation dumps to:

```text
results/registers.txt
results/data_memory.txt
```

Each simulation overwrites these result files.

## Memory configuration

| Memory | Default capacity | Organization | Size |
|---|---:|---:|---:|
| Instruction RAM | 16,384 words | 32 bits per word | 64 KiB |
| Data RAM | 2,048 words | 64 bits per word | 16 KiB |

The data RAM is byte-addressed with eight byte lanes per word. Although the core uses 64-bit architectural addresses, the data RAM selects locations using the low 14 address bits. Addresses separated by 16 KiB therefore alias to the same data-memory location. Keep the program's data, stack, and arrays within the 16 KiB window.

## RTL map

| File(s) | Purpose |
|---|---|
| `RISC_V_Core.v` | Top-level core and pipeline connections |
| `fetch.v`, `decode.v`, `execute.v`, `memory.v`, `writeback.v` | Main pipeline units |
| `fetch_pipe.v`, `decode_pipe.v`, `execute_pipe.v`, `memory_pipe.v` | Pipeline registers |
| `control_unit.v`, `stallControl.v`, `ALU.v` | Instruction control, hazard handling, and arithmetic/logic operations |
| `bsram.v`, `bram.v`, `i_mem_interface.v`, `d_mem_interface.v`, `memory_hierarchy.v` | Memories and memory interfaces |
| `semihost_putchar.v` | Semihosted character output |
| `tb/tb_RISC_V_Core.v` | Simulation testbench |

## Notes

- `llvm/mul` uses inline assembly to exercise individual RV64M instructions.
- The RTL implements division and remainder with Verilog operators; verify edge cases such as division by zero before relying on them.
- License and project attribution are in [`LICENSE`](LICENSE).
