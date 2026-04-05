#!/bin/bash
# ============================================================
# update_app_only.sh
#
# Quick update: only re-flash the application region.
# Bitstream and bootloader stay untouched.
#
# Use this when you ONLY changed app code, not the bootloader.
# ============================================================

set -e

APP_ELF="path/to/app/Debug/app.elf"
FLASH_OFFSET="0x300000"
FLASH_TYPE="s25fl128sxxxxxx0-spi-x1_x2_x4"
OUTPUT_DIR="./output"

mkdir -p ${OUTPUT_DIR}

# Step 1: ELF -> raw binary
echo "=== objcopy ==="
riscv64-unknown-elf-objcopy -O binary ${APP_ELF} ${OUTPUT_DIR}/app.bin

# Step 2: Add boot header
echo "=== pack_image ==="
python3 pack_image.py ${OUTPUT_DIR}/app.bin ${OUTPUT_DIR}/app_packed.bin

# Step 3: Flash only the app region
echo "=== Flash app at ${FLASH_OFFSET} ==="
vivado -mode batch -source - <<EOF
write_cfgmem -format mcs -size 4 \
    -interface spix1 \
    -loaddata "up ${FLASH_OFFSET} ${OUTPUT_DIR}/app_packed.bin" \
    -file ${OUTPUT_DIR}/app_only.mcs -force
EOF

vivado -mode batch -source - <<EOF
open_hw_manager
connect_hw_server
open_hw_target
set device [lindex [get_hw_devices] 0]
current_hw_device \$device
program_cfgmem -memtype spi -file ${OUTPUT_DIR}/app_only.mcs \
    -hw_cfgmem [create_hw_cfgmem -hw_device \$device \
    -mem_dev [lindex [get_cfgmem_parts ${FLASH_TYPE}] 0]]
close_hw_target
close_hw_manager
EOF

echo ""
echo "=== Done! Power cycle to run new app. ==="
