/*
 * app_lscript.ld
 *
 * Linker script for MicroBlaze RISC-V application
 * Everything placed in SRAM (512 KB)
 * Loaded by bootloader from QSPI Flash
 */

MEMORY {
    sram : ORIGIN = 0x60000000, LENGTH = 512K
}

ENTRY(_start)

SECTIONS {
    .text : {
        *(.vectors)
        *(.boot)
        *(.text)
        *(.text.*)
    } > sram

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > sram

    .data : {
        *(.data)
        *(.data.*)
    } > sram

    .sdata : {
        *(.sdata)
        *(.sdata.*)
        *(.gnu.linkonce.s.*)
    } > sram

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        __bss_end = .;
    } > sram

    .heap (NOLOAD) : {
        . = ALIGN(16);
        _heap_start = .;
        . += 64K;
        _heap_end = .;
    } > sram

    .stack (NOLOAD) : {
        . = ALIGN(16);
        _stack_end = .;
        . += 8K;
        _stack_top = .;
    } > sram

    ASSERT(. <= 0x60080000, "ERROR: Application exceeds 512 KB SRAM!")
}
