# Release — Pre-built Outputs

This directory contains pre-built outputs for the MicroBlaze RISC-V MCU design on the Cmod A7-35T. You can use these files directly without rebuilding the Vivado project.

## Files

| File | Description |
|------|-------------|
| `top.bit` | Pre-built bitstream, ready to program onto the Cmod A7-35T |
| `top_wrapper.xsa` | Hardware export (XSA) for creating a Vitis platform |

## Usage

### Create a Vitis Platform

Open Vitis 2025.2 and create a new platform using `top_wrapper.xsa`. Select **standalone** OS and **microblaze_riscv_0** as the processor.

> If you need to modify the hardware design, use `RISC-V-MCU/top.tcl` to rebuild the Vivado project from source.
