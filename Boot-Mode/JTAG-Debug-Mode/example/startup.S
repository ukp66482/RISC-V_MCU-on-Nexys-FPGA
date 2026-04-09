/*
 * startup.S - Bare-metal RISC-V startup + trap handler
 *
 * _start:
 *   1. Set mtvec → _trap_handler (direct mode)
 *   2. Disable all interrupts (mie = 0)
 *   3. Set global pointer (gp) for small-data optimisation
 *   4. Set stack pointer (sp)
 *   5. Zero BSS
 *   6. Call main()
 *   7. Halt if main() returns
 *
 * _trap_handler:
 *   Saves all caller-saved registers, calls trap_dispatch() in C,
 *   restores registers, executes mret.
 *   Handles both synchronous exceptions and interrupts.
 */

/* -----------------------------------------------------------------------
 * _start
 * --------------------------------------------------------------------- */
    .section .text.init, "ax", @progbits
    .global  _start
    .type    _start, @function

_start:
    /* 1. Trap vector — direct mode (bits[1:0]=00) */
    la      t0, _trap_handler
    csrw    mtvec, t0

    /* 2. Disable all interrupts until main() sets them up */
    csrw    mie, zero

    /* 3. Global pointer (norelax to prevent self-relative optimisation) */
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop

    /* 4. Stack pointer */
    la      sp, _stack_top

    /* 5. Zero BSS */
    la      t0, __bss_start
    la      t1, __bss_end
.Lclear_bss:
    bgeu    t0, t1, .Ldone_bss
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       .Lclear_bss
.Ldone_bss:

    /* 6. Call main */
    call    main

    /* 7. Halt */
.Lhalt:
    j       .Lhalt


/* -----------------------------------------------------------------------
 * _trap_handler — saves caller-saved registers, calls trap_dispatch(),
 *                 restores, mret.
 *
 * Caller-saved (ABI ilp32): ra, t0-t6, a0-a7  → 15 registers × 4 = 60 B
 * We round up to 16 slots (64 bytes) for 16-byte stack alignment.
 * --------------------------------------------------------------------- */
    .section .text, "ax", @progbits
    .global  _trap_handler
    .type    _trap_handler, @function
    .align   2                      /* mtvec requires 4-byte alignment */

_trap_handler:
    /* Allocate stack frame */
    addi    sp, sp, -(16*4)

    /* Save caller-saved registers */
    sw      ra,   0*4(sp)
    sw      t0,   1*4(sp)
    sw      t1,   2*4(sp)
    sw      t2,   3*4(sp)
    sw      a0,   4*4(sp)
    sw      a1,   5*4(sp)
    sw      a2,   6*4(sp)
    sw      a3,   7*4(sp)
    sw      a4,   8*4(sp)
    sw      a5,   9*4(sp)
    sw      a6,  10*4(sp)
    sw      a7,  11*4(sp)
    sw      t3,  12*4(sp)
    sw      t4,  13*4(sp)
    sw      t5,  14*4(sp)
    sw      t6,  15*4(sp)

    /* Dispatch to C handler */
    call    trap_dispatch

    /* Restore caller-saved registers */
    lw      ra,   0*4(sp)
    lw      t0,   1*4(sp)
    lw      t1,   2*4(sp)
    lw      t2,   3*4(sp)
    lw      a0,   4*4(sp)
    lw      a1,   5*4(sp)
    lw      a2,   6*4(sp)
    lw      a3,   7*4(sp)
    lw      a4,   8*4(sp)
    lw      a5,   9*4(sp)
    lw      a6,  10*4(sp)
    lw      a7,  11*4(sp)
    lw      t3,  12*4(sp)
    lw      t4,  13*4(sp)
    lw      t5,  14*4(sp)
    lw      t6,  15*4(sp)

    /* Free stack frame and return from trap */
    addi    sp, sp, 16*4
    mret
