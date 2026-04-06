# JTAG Debug Mode — MicroBlaze RISC-V on Cmod A7-35T

## Overview

JTAG debug mode allows direct loading and execution of application code
via a JTAG connection, bypassing the bootloader and QSPI Flash entirely.
This mode uses the **same bitstream and same hardware design** as
standalone boot mode — no hardware modification is needed.

All operations are performed through **XSDB** (Xilinx System Debugger),
a command-line tool included in Vivado/Vitis installations.

## How It Works

The key component is `mdm_riscv` (MicroBlaze Debug Module for RISC-V),
which implements the **RISC-V Debug Specification**. It exposes debug
registers accessible over JTAG:

| Debug Register  | Purpose                                    |
|-----------------|--------------------------------------------|
| `dmcontrol`     | Halt and resume the CPU                    |
| `abstractcs`    | Trigger abstract commands                  |
| `command`       | Read/write CPU GPRs and CSRs               |
| `progbuf`       | Inject instructions for CPU to execute     |

Memory access is performed through **abstract commands** — the debug
module instructs the CPU to execute load/store operations internally.
This means any address in the CPU's address map is reachable

## Boot Flow

```
FPGA already configured (bitstream loaded)
  │
  ▼
XSDB connects to JTAG target
  │
  ▼
mdm_riscv halts CPU at reset vector (0x00000000)
  │  ← Bootloader in BRAM never executes
  ▼
XSDB parses app.elf:
  ├─ Reads ELF program headers → identifies loadable sections
  ├─ Reads ELF header e_entry field → gets entry point (0x60000000)
  │
  ▼
XSDB writes ELF sections to SRAM via JTAG path:
  │
  │  XSDB ──JTAG──→ mdm_riscv ──abstract cmd──→ CPU ──AXI──→ SRAM
  │                                                     │
  │                             smartconnect (M18_AXI) ─┘
  │                                     │
  │                                 axi_emc_0
  │                                     │
  │                              Cellular RAM
  │                              (0x60000000)
  │
  ▼
XSDB writes dpc CSR = 0x60000000 (Debug PC)
  │  ← Sets where CPU will resume execution
  ▼
CPU resumes → starts executing from 0x60000000
```

## Comparison with Standalone Boot

| Aspect           | JTAG Debug Mode              | Standalone Boot Mode          |
|------------------|------------------------------|-------------------------------|
| Who loads app    | XSDB (over JTAG)             | Bootloader (from QSPI Flash) |
| App destination  | SRAM 0x60000000              | SRAM 0x60000000               |
| Entry point      | Read from ELF `e_entry`      | Read from boot header         |
| PC setup         | XSDB writes `dpc` CSR        | Bootloader jumps to address   |
| CRC verification | Not needed (direct write)    | Bootloader checks CRC32      |
| Bitstream        | Same                         | Same                          |
| Linker script    | Same (`app_lscript.ld`)      | Same (`app_lscript.ld`)       |
| Bootloader       | Not executed (CPU halted)    | Runs from BRAM                |
| Use case         | Development & debugging      | Production deployment         |

## Required Files

Only the standard application build output is needed:

| File              | Purpose                                      |
|-------------------|----------------------------------------------|
| `app.elf`         | Application ELF (linked to 0x60000000)       |
| `app_lscript.ld`  | Linker script (shared with standalone mode)  |
| `top.bit`         | Bitstream (shared with standalone mode)       |
| `top_wrapper.xsa` | Hardware description for Vitis platform       |

No `pack_image.py`, no `objcopy`, no flash scripts.

## Step-by-Step Usage with XSDB

### 1. Build the Application

Build `app.elf` using Vitis or directly with `mb-riscv32-unknown-elf-gcc`:

```bash
mb-riscv32-unknown-elf-gcc \
    -T app_lscript.ld \
    -o app.elf \
    your_app.c
```

### 2. Launch XSDB

```bash
xsdb
```

### 3. Connect and Program FPGA

```tcl
# Connect to the JTAG cable
connect

# List available targets to verify connection
targets

# Program the FPGA with the bitstream (if not already loaded)
fpga top.bit
```

### 4. Select the CPU Target

```tcl
# List targets — you should see something like:
#   1  APU
#     2  MicroBlaze RISC-V #0 (Running)
targets

# Select the MicroBlaze RISC-V target
target 2
```

> **Note:** The target number may vary. Look for the entry that says
> `MicroBlaze RISC-V`.

### 5. Stop the CPU and Load the ELF

```tcl
# Stop (halt) the CPU — prevents bootloader from running
stop

# Download app.elf into memory
# XSDB reads the ELF, writes each section to its load address (0x60000000),
# and sets PC to the e_entry value automatically
dow app.elf
```

### 6. Run

```tcl
# Resume execution — CPU starts from 0x60000000
con
```

### 7. (Optional) Debug Commands

```tcl
# Stop execution
stop

# Read the program counter
rrd pc

# Read all registers
rrd

# Step one instruction
step

# Read memory at address (e.g., first 16 bytes of SRAM)
mrd 0x60000000 4

# Write memory
mwr 0x60000000 0xDEADBEEF

# Set a software breakpoint at an address
bpadd -addr 0x60000100

# List breakpoints
bplist

# Remove breakpoint
bpremove 0

# Resume
con

# Reset the CPU (will run bootloader unless you stop immediately)
rst
stop
```

### 8. Quick Reload (After Recompiling)

```tcl
stop
dow app.elf
con
```

No flash programming needed — the entire cycle stays in JTAG.

### One-Liner Script

Save as `jtag_run.tcl` and execute with `xsdb jtag_run.tcl`:

```tcl
connect
fpga top.bit
after 100
targets
target 2
stop
dow app.elf
con
```

## Memory Map Reference

```
Address          Device              Access via
──────────────────────────────────────────────────────
0x00000000       BRAM (128 KB)       LMB (bootloader lives here)
0x60000000       SRAM (512 KB)       AXI → axi_emc_0 (app runs here)
0x40000000+      Peripherals         AXI → smartconnect
──────────────────────────────────────────────────────
```

In JTAG mode, the debugger can read/write all of these through the
`mdm_riscv` → CPU → AXI path.

## Troubleshooting

| Symptom                          | Cause                              | Fix                                     |
|----------------------------------|------------------------------------|-----------------------------------------|
| `connect` fails                 | JTAG cable not detected            | Check USB connection, install cable drivers |
| No targets listed               | Bitstream not loaded               | Run `fpga top.bit` first                |
| CPU runs bootloader before halt | `stop` issued too late             | Run `stop` immediately after `target 2` |
| `dow` fails or hangs            | Wrong target selected              | Run `targets` and verify correct target number |
| App crashes immediately         | Wrong linker script (BRAM instead of SRAM) | Verify `app_lscript.ld` uses 0x60000000 |
| Cannot read SRAM via `mrd`      | AXI EMC not in address map         | Check Vivado block design               |
| Breakpoints not hitting         | ELF mismatch with source           | Rebuild and re-run `dow app.elf`        |
