# jtag_run.tcl - Load and run gpio-toggle-example via XSDB
#
# Usage:
#   xsdb jtag_run.tcl
#
# Prerequisites:
#   1. Cmod A7-35T connected via USB (JTAG)
#   2. app.elf built (run: make)
#   3. top.bit available at the path below

# -----------------------------------------------------------------------
# Paths - adjust if needed
# -----------------------------------------------------------------------
set BIT_FILE  "../../../Cmod-A7-spec/top.bit"
set ELF_FILE  "app.elf"

# -----------------------------------------------------------------------
# Connect to JTAG cable
# -----------------------------------------------------------------------
puts "=== Connecting to JTAG ==="
connect

# -----------------------------------------------------------------------
# Program the FPGA
# -----------------------------------------------------------------------
puts "=== Programming FPGA with $BIT_FILE ==="
fpga $BIT_FILE

# Wait for design to come up after configuration
after 200

# -----------------------------------------------------------------------
# Select Hart #0 (CPU core)
#
# Target hierarchy on Cmod A7-35T:
#   1  xc7a35t
#      4  BSCAN JTAG at USER2
#      5  RISC-V at USER2
#         6  Hart #0  <-- CPU
# -----------------------------------------------------------------------
puts "=== Available targets ==="
targets

puts "=== Selecting Hart #0 (target 6) ==="
targets 6

# -----------------------------------------------------------------------
# Halt the CPU before it runs the bootloader
# -----------------------------------------------------------------------
puts "=== Halting CPU ==="
stop

# -----------------------------------------------------------------------
# Download ELF into SRAM (0x60000000) and set PC to entry point
# -----------------------------------------------------------------------
puts "=== Loading $ELF_FILE ==="
dow $ELF_FILE

# -----------------------------------------------------------------------
# Resume execution
# -----------------------------------------------------------------------
puts "=== Running - GPIO A~D should toggle at 1 Hz ==="
con

puts "=== Done. Use 'stop' in xsdb to halt, 'rrd' to inspect registers ==="
