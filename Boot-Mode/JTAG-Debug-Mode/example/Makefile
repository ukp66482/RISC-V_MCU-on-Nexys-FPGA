# Makefile - GPIO toggle example (no Xilinx BSP)
#
# Toolchain: riscv64-unknown-elf-gcc from /opt/riscv/bin/
# Target:    MicroBlaze RISC-V on Cmod A7-35T (RV32IMB)
#
# Usage:
#   make          — build app.elf
#   make clean    — remove build outputs
#   make flash    — load via XSDB (requires Vivado/Vitis on PATH)

# -----------------------------------------------------------------------
# Toolchain
# -----------------------------------------------------------------------
CROSS  := /opt/riscv/bin/riscv64-unknown-elf
CC     := $(CROSS)-gcc
AS     := $(CROSS)-gcc   # use gcc as assembler (handles .S preprocessing)
LD     := $(CROSS)-gcc
OBJDUMP := $(CROSS)-objdump
SIZE    := $(CROSS)-size

# -----------------------------------------------------------------------
# Architecture flags (match existing workspace: rv32imb + standard exts)
# -----------------------------------------------------------------------
ARCH_FLAGS := -march=rv32imb_zicsr_zifencei_zbc -mabi=ilp32

# -----------------------------------------------------------------------
# Compiler flags
# -----------------------------------------------------------------------
CFLAGS  := $(ARCH_FLAGS)
CFLAGS  += -O1 -g3
CFLAGS  += -Wall -Wextra
CFLAGS  += -ffreestanding   # do not assume standard library entry points
CFLAGS  += -fno-builtin     # do not substitute builtin function calls
CFLAGS  += -ffunction-sections -fdata-sections   # allow linker GC

ASFLAGS := $(ARCH_FLAGS) -g3

LDFLAGS := $(ARCH_FLAGS)
LDFLAGS += -T lscript.ld
LDFLAGS += -nostartfiles    # do not link crt0 from toolchain
LDFLAGS += -nostdlib        # do not link libc/libgcc automatically
LDFLAGS += -Wl,--gc-sections
LDFLAGS += -Wl,-Map,app.map
LDFLAGS += -Wl,--no-warn-rwx-segments

# -----------------------------------------------------------------------
# Sources
# -----------------------------------------------------------------------
TARGET  := app.elf

C_SRCS  := main.c gpio.c timer.c trap.c intc.c
AS_SRCS := startup.S

OBJS := $(C_SRCS:.c=.o) $(AS_SRCS:.S=.o)

# -----------------------------------------------------------------------
# Rules
# -----------------------------------------------------------------------
.PHONY: all clean flash disasm

all: $(TARGET)
	@$(SIZE) $<

$(TARGET): $(OBJS) lscript.ld
	$(LD) $(LDFLAGS) $(OBJS) -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(AS) $(ASFLAGS) -c $< -o $@

# Annotated disassembly (useful for debugging without a terminal)
disasm: $(TARGET)
	$(OBJDUMP) -d -S $< > app.dis

# Load via XSDB (Vivado must be on PATH)
flash: $(TARGET)
	xsdb jtag_run.tcl

clean:
	rm -f $(OBJS) $(TARGET) app.map app.dis trap.o intc.o
