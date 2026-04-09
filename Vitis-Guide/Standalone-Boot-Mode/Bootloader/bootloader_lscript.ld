/*
 * bootloader_lscript.ld
 *
 * Linker script for MicroBlaze RISC-V bootloader
 * Everything placed in BRAM (128 KB)
 */

MEMORY {
    bram : ORIGIN = 0x00000000, LENGTH = 128K
}

ENTRY(_start)

SECTIONS {
    .text : {
        *(.vectors)
        *(.boot)
        *(.text)
        *(.text.*)
    } > bram

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > bram

    .data : {
        *(.data)
        *(.data.*)
    } > bram

    .sdata : {
        *(.sdata)
        *(.sdata.*)
        *(.gnu.linkonce.s.*)
    } > bram

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        __bss_end = .;
    } > bram

    .stack (NOLOAD) : {
        . = ALIGN(16);
        _stack_end = .;
        . += 4K;
        _stack_top = .;
    } > bram

    ASSERT(. <= 0x00020000, "ERROR: Bootloader exceeds 128 KB BRAM!")
}
