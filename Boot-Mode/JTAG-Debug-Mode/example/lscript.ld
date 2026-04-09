/*
 * lscript.ld - Linker script for bare-metal GPIO toggle example
 *
 * Memory layout (Cmod A7-35T, MicroBlaze RISC-V):
 *   BRAM  0x00000000  128 KB  (bootloader lives here — not used in JTAG mode)
 *   SRAM  0x60000000  512 KB  (application runs here via AXI EMC)
 *
 * JTAG debug mode: XSDB loads this ELF into SRAM and sets PC = 0x60000000.
 * No flash or bootloader involvement.
 */

_STACK_SIZE = 8K;
_HEAP_SIZE  = 0;    /* no dynamic allocation in this example */

MEMORY {
    sram : ORIGIN = 0x60000000, LENGTH = 512K
}

ENTRY(_start)

SECTIONS {

    /* Startup code first — _start lands here */
    .text.init : {
        KEEP(*(.text.init))
    } > sram

    .text : {
        . = ALIGN(4);
        *(.text)
        *(.text.*)
        *(.gnu.linkonce.t.*)
    } > sram

    .rodata : {
        . = ALIGN(4);
        *(.rodata)
        *(.rodata.*)
        *(.gnu.linkonce.r.*)
    } > sram

    .srodata : {
        *(.srodata)
        *(.srodata.*)
    } > sram

    .data : {
        . = ALIGN(4);
        __data_start = .;
        *(.data)
        *(.data.*)
        *(.gnu.linkonce.d.*)
        _edata = .;
    } > sram

    .sdata : {
        __sdata_start = .;
        *(.sdata)
        *(.sdata.*)
        *(.gnu.linkonce.s.*)
        __sdata_end = .;
    } > sram

    /* Global pointer for small-data optimisation */
    __global_pointer$ = MIN(__sdata_start + 0x800,
                            MAX(__data_start + 0x800, __bss_end - 0x800));

    .bss (NOLOAD) : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > sram

    .heap (NOLOAD) : {
        . = ALIGN(16);
        _heap_start = .;
        . += _HEAP_SIZE;
        _heap_end = .;
    } > sram

    .stack (NOLOAD) : {
        . = ALIGN(16);
        _stack_end = .;
        . += _STACK_SIZE;
        . = ALIGN(16);
        _stack_top = .;
    } > sram

    _end = .;

    ASSERT(. <= 0x60080000, "ERROR: Image exceeds 512 KB SRAM!")
}
