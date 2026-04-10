# RISC-V MCU — Vivado Hardware Design

Tcl rebuild script and IP peripheral reference for the MicroBlaze RISC-V MCU block design on the Cmod A7-35T.

## Files

| File / Directory | Description |
|------------------|-------------|
| `top.tcl` | Vivado Tcl script — rebuilds the full block design, adds XDC constraints, and creates the HDL wrapper automatically |
| [IP-Specification/](IP-Specification/Cmod_A7_IP_Peripheral_Reference.md) | AXI IP list, base addresses, parameters, interrupt mapping |

## Usage

Open Vivado 2025.2 and run:

```tcl
source RISC-V-MCU/top.tcl
```

The script will:
1. Create a Vivado project named `RISC-V-MCU` inside this directory
2. Reconstruct the full MicroBlaze RISC-V block design
3. Add the XDC constraints from `Cmod-A7-spec/Cmod-A7-Master.xdc`
4. Generate and set the HDL wrapper as the top module

> Pre-built outputs (`top.bit`, `top_wrapper.xsa`) are in [`../release/`](../release/).
