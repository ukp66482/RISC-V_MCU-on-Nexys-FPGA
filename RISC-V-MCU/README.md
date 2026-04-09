# RISC-V MCU — Vivado Hardware Design

Pre-built outputs, Tcl rebuild script, and IP peripheral reference for the MicroBlaze RISC-V MCU block design.

## Files

| File | Description |
|------|-------------|
| `top.tcl` | Vivado Tcl script — recreates the full block design (processor, peripherals, interconnect) |
| `top.bit` | Pre-built bitstream, ready to program onto the Cmod A7-35T |
| `top_wrapper.xsa` | Hardware export (XSA) for creating a Vitis platform |
| [IP-Specification/](IP-Specification/Cmod_A7_IP_Peripheral_Reference.md) | AXI IP list, base addresses, parameters, interrupt mapping |
