# RISC-V MCU on Cmod A7

A soft-core RISC-V MCU system built on the **Digilent Cmod A7-35T** (Xilinx Artix-7, xc7a35tcpg236-1), designed for the **NCKU Microprocessor Principles and Applications** course.

## Overview

This project provides a ready-to-use RISC-V MCU environment on the Cmod A7-35T for the **NCKU Microprocessor Principles and Applications** course. Students write and run firmware targeting a MicroBlaze RISC-V processor with a set of pre-configured peripherals, focusing on software-level interaction such as register programming, interrupt handling, and peripheral control — without needing to deal with FPGA or circuit-level details.

![Digilent Cmod A7-35T](docs/images/cmod-a7-0.png)

### System Architecture

![System Architecture](docs/images/system_architecture.svg)

### Key Specifications

| Item | Detail |
|------|--------|
| FPGA | Xilinx Artix-7 xc7a35tcpg236-1 |
| Processor | MicroBlaze RISC-V (32-bit, RV32IM + Bitmanip) |
| System Clock | 100 MHz (PLL from 12 MHz on-board oscillator) |
| Local Memory | 128 KB (Block RAM, 128 KB Instruction + Data, shared True Dual-Port) |
| Interconnect | AXI SmartConnect (20 peripheral ports) |
| Toolchain | Vivado & Vitis 2025.2 |

![Cmod A7-35T DIP Pinout](Cmod-A7-spec/Pin-Specification/images/pinout_diagram.png)

### Peripherals

- **GPIO** — 4 × 7-bit bidirectional DIP groups (A–D), on-board LEDs × 2, RGB LED, push button
- **PWM** — 3 channels (axi_timer, DIP Pin 10 / 34 / 40)
- **UART** — 2 × 16550 (USB Micro-USB + DIP Pin 11/12 external)
- **Timers** — 3 × 32-bit general-purpose (with interrupt)
- **Interrupt Controller** — 6-channel AXI INTC
- **XADC** — 12-bit ADC, 500 KSPS aggregate / 100 KSPS per channel (2 external analog inputs)
- **QSPI Flash** — On-board Quad-SPI flash
- **SRAM** — 512 KB external cellular RAM (axi_emc, 32 MB address range)

## Repository Structure

```
├── Cmod-A7-spec/                    # Board documentation & hardware files
│   ├── IP-Specification/            # IP peripheral reference
│   │   └── images/
│   ├── Pin-Specification/           # Pin mapping & electrical characteristics
│   │   └── images/
│   ├── Power-Specification/         # Power rails & supply design
│   │   └── images/
│   ├── Kicad_symbol/                # KiCad schematic symbol
│   ├── Cmod-A7-Master.xdc          # FPGA pin constraints file
│   ├── top.tcl                      # Vivado project rebuild script
│   └── top_wrapper.xsa              # Hardware export for Vitis platform
├── docs/
│   ├── images/                      # Project-level diagrams
│   │   └── system_architecture.svg
│   └── pdf-style.css                # PDF export style (Markdown PDF extension)
├── Intro_PPT/                       # Course introduction slides
│   ├── RISCV-MCU.pdf
│   └── RISCV-MCU.pptx
├── workspace-example/               # Vitis firmware examples (source only)
│   ├── GPIO_test/src/               # GPIO peripheral test
│   ├── PWM_test/src/                # PWM servo motor control
│   └── UART_test/src/               # UART communication test
└── .gitignore
```

## Prerequisites

- **Vivado 2025.2** — for synthesizing and implementing the FPGA design, and programming the bitstream
- **Vitis 2025.2** — for creating the hardware platform and developing firmware applications

## Getting Started

### 1. Rebuild the Vivado Project

Open Vivado 2025.2 and run:

```tcl
source Cmod-A7-spec/top.tcl
```

Or use the pre-built bitstream (`Cmod-A7-spec/top.bit`) directly.

### 2. Create a Vitis Application

1. Open Vitis 2025.2 and create a new platform using `Cmod-A7-spec/top_wrapper.xsa`.
2. Create a new application project targeting the MicroBlaze RISC-V processor.
3. Copy source files from one of the examples in `workspace-example/` into your project.
4. Build and program the FPGA.

### 3. Run an Example

The `workspace-example/` directory contains three ready-to-use test programs:

- **GPIO_test** — Toggle LEDs and read button/switch inputs
- **PWM_test** — Drive a servo motor via PWM output
- **UART_test** — Send and receive data over UART

## Documentation

All board-level documentation is in [`Cmod-A7-spec/`](Cmod-A7-spec/):

| Document | Description |
|----------|-------------|
| [IP Peripheral Reference](Cmod-A7-spec/IP-Specification/Cmod_A7_IP_Peripheral_Reference.md) | Full AXI IP list, base addresses, parameters, interrupt mapping |
| [Pin Specification](Cmod-A7-spec/Pin-Specification/Cmod_A7_Pin_Specification.md) | DIP connector pin map, GPIO/PWM/UART/ADC assignments, electrical characteristics |
| [Power Specification](Cmod-A7-spec/Power-Specification/Cmod_A7_Power_Specification.md) | Power rails, input options, VU pin behavior, dual-supply considerations |

## License

This project is developed for educational use at National Cheng Kung University (NCKU).
