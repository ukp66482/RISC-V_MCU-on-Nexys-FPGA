#!/bin/bash
# ============================================================
# build_and_flash.sh
#
# Cmod A7-35T MicroBlaze RISC-V Boot Flow
# Complete build and flash workflow
#
# Prerequisites:
#   - Vivado 2025.2 on PATH
#   - Vitis 2025.2 RISC-V toolchain on PATH
#   - Python 3 with standard library
# ============================================================

set -e

# ---- Configuration (edit these paths) ----
VIVADO_PROJECT="path/to/your/project"
BIT_FILE="${VIVADO_PROJECT}/top.runs/impl_1/top_wrapper.bit"
MMI_FILE="${VIVADO_PROJECT}/top.runs/impl_1/top_wrapper.mmi"
PROC_PATH="top_i/microblaze_riscv_0"

BOOTLOADER_ELF="path/to/bootloader/Debug/bootloader.elf"
APP_ELF="path/to/app/Debug/app.elf"

FLASH_OFFSET="0x300000"
FLASH_TYPE="s25fl128sxxxxxx0-spi-x1_x2_x4"  # Adjust for your Flash chip
OUTPUT_DIR="./output"

mkdir -p ${OUTPUT_DIR}

# ============================================================
# Step 1: Merge bootloader into bitstream
#         (only needed when bootloader changes)
# ============================================================
echo "=== Step 1: updatemem ==="
updatemem -meminfo ${MMI_FILE} \
          -bit ${BIT_FILE} \
          -data ${BOOTLOADER_ELF} \
          -proc ${PROC_PATH} \
          -out ${OUTPUT_DIR}/download.bit
echo "Output: ${OUTPUT_DIR}/download.bit"

# ============================================================
# Step 2: Convert app ELF to raw binary
# ============================================================
echo "=== Step 2: objcopy ==="
riscv64-unknown-elf-objcopy -O binary ${APP_ELF} ${OUTPUT_DIR}/app.bin
echo "Output: ${OUTPUT_DIR}/app.bin"

# ============================================================
# Step 3: Pack app binary with boot header
# ============================================================
echo "=== Step 3: pack_image ==="
python3 pack_image.py ${OUTPUT_DIR}/app.bin ${OUTPUT_DIR}/app_packed.bin
echo "Output: ${OUTPUT_DIR}/app_packed.bin"

# ============================================================
# Step 4: Generate .mcs file (bitstream + app combined)
# ============================================================
echo "=== Step 4: write_cfgmem ==="
vivado -mode batch -source - <<EOF
write_cfgmem -format mcs -size 4 \
    -interface spix1 \
    -loadbit  "up 0x000000 ${OUTPUT_DIR}/download.bit" \
    -loaddata "up ${FLASH_OFFSET} ${OUTPUT_DIR}/app_packed.bin" \
    -file ${OUTPUT_DIR}/combined.mcs -force
EOF
echo "Output: ${OUTPUT_DIR}/combined.mcs"

# ============================================================
# Step 5: Program Flash
# ============================================================
echo "=== Step 5: Program Flash ==="
vivado -mode batch -source - <<EOF
open_hw_manager
connect_hw_server
open_hw_target
set device [lindex [get_hw_devices] 0]
current_hw_device \$device
program_cfgmem -memtype spi -file ${OUTPUT_DIR}/combined.mcs \
    -hw_cfgmem [create_hw_cfgmem -hw_device \$device \
    -mem_dev [lindex [get_cfgmem_parts ${FLASH_TYPE}] 0]]
close_hw_target
close_hw_manager
EOF

echo ""
echo "=== Done! Power cycle the board to boot. ==="
