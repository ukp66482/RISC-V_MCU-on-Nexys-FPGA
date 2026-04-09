/*
 * bootloader.c
 * 
 * First-stage bootloader for MicroBlaze RISC-V on Cmod A7-35T
 * Runs from BRAM (0x00000000), reads a boot header from QSPI Flash,
 * copies application to SRAM (0x60000000), verifies CRC32, then jumps.
 *
 * Boot Header Layout (16 bytes at FLASH_HEADER_OFFSET):
 *   [0:3]   magic      = 0xDEADBEEF
 *   [4:7]   app_size   = size of app binary in bytes
 *   [8:11]  entry_addr = jump target (typically 0x60000000)
 *   [12:15] crc32      = CRC32 of app binary
 *
 * Constraints:
 *   - No interrupts (polling only)
 *   - Standard SPI Read (0x03) for maximum Flash compatibility
 *   - Total code+data+stack must fit in 128 KB BRAM
 *
 * Target: Vitis 2025.2, SDT flow, MicroBlaze RISC-V
 */

#include <stdint.h>

/* ========== Configuration ========== */

#define FLASH_HEADER_OFFSET   0x00300000      /* Boot header location in Flash */
#define BOOT_HEADER_SIZE      16              /* 4 x uint32_t */
#define SRAM_BASE_ADDR        0x60000000      /* Default app destination */
#define APP_MAX_SIZE          (480 * 1024)    /* Safety cap: SRAM is 512 KB */
#define BOOT_MAGIC            0xDEADBEEF

/* Enable UART debug messages (comment out to save code space) */
#define BOOTLOADER_DEBUG

/* ========== Boot Header ========== */

typedef struct {
    uint32_t magic;       /* Must be BOOT_MAGIC */
    uint32_t app_size;    /* App binary size in bytes */
    uint32_t entry_addr;  /* Entry point address */
    uint32_t crc32;       /* CRC32 of app binary */
} boot_header_t;

/* ========== Hardware Addresses ========== */

/* AXI Quad SPI (PG153) */
#define SPI_BASE              0x44A20000
#define SPI_SRR               (*(volatile uint32_t *)(SPI_BASE + 0x40))
#define SPI_CR                (*(volatile uint32_t *)(SPI_BASE + 0x60))
#define SPI_SR                (*(volatile uint32_t *)(SPI_BASE + 0x64))
#define SPI_DTR               (*(volatile uint32_t *)(SPI_BASE + 0x68))
#define SPI_DRR               (*(volatile uint32_t *)(SPI_BASE + 0x6C))
#define SPI_SSR               (*(volatile uint32_t *)(SPI_BASE + 0x70))
#define SPI_DGIER             (*(volatile uint32_t *)(SPI_BASE + 0x1C))

#define SPI_CR_SPE            (1 << 1)
#define SPI_CR_MASTER         (1 << 2)
#define SPI_CR_TXFIFO_RST     (1 << 5)
#define SPI_CR_RXFIFO_RST     (1 << 6)
#define SPI_CR_MANUAL_SS      (1 << 7)
#define SPI_CR_MASTER_INHIBIT (1 << 8)

#define SPI_SR_RX_EMPTY       (1 << 0)
#define SPI_SR_TX_EMPTY       (1 << 2)

#define CMD_READ              0x03
#define CMD_RDID              0x9F

/* UART 16550 (USB UART) */
#ifdef BOOTLOADER_DEBUG
#define UART_BASE             0x44A00000
#define UART_THR              (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_LSR              (*(volatile uint32_t *)(UART_BASE + 0x14))
#define UART_LCR              (*(volatile uint32_t *)(UART_BASE + 0x0C))
#define UART_DLL              (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_DLM              (*(volatile uint32_t *)(UART_BASE + 0x04))

#define UART_LSR_TX_EMPTY     (1 << 5)
#define UART_LCR_DLAB         (1 << 7)
#define UART_LCR_8N1          0x03
#define UART_DIVISOR          54   /* 100 MHz / 16 / 115200 */
#endif

/* ========== UART ========== */

#ifdef BOOTLOADER_DEBUG
static void uart_init(void)
{
    UART_LCR = UART_LCR_DLAB | UART_LCR_8N1;
    UART_DLL = UART_DIVISOR & 0xFF;
    UART_DLM = (UART_DIVISOR >> 8) & 0xFF;
    UART_LCR = UART_LCR_8N1;
}

static void uart_putc(char c)
{
    while (!(UART_LSR & UART_LSR_TX_EMPTY));
    UART_THR = c;
}

static void uart_puts(const char *s)
{
    while (*s) {
        if (*s == '\n') uart_putc('\r');
        uart_putc(*s++);
    }
}

static void uart_put_hex32(uint32_t val)
{
    const char hex[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4)
        uart_putc(hex[(val >> i) & 0xF]);
}
#else
#define uart_init()
#define uart_puts(s)
#define uart_put_hex32(v)
#endif

/* ========== CRC32 ========== */

static uint32_t crc32(const uint8_t *data, uint32_t len)
{
    uint32_t crc = 0xFFFFFFFF;
    for (uint32_t i = 0; i < len; i++) {
        crc ^= data[i];
        for (int j = 0; j < 8; j++) {
            if (crc & 1)
                crc = (crc >> 1) ^ 0xEDB88320;
            else
                crc >>= 1;
        }
    }
    return ~crc;
}

/* ========== SPI ========== */

static void spi_init(void)
{
    SPI_SRR = 0x0000000A;
    for (volatile int i = 0; i < 100; i++);

    SPI_DGIER = 0;
    SPI_CR = SPI_CR_MASTER | SPI_CR_SPE | SPI_CR_MANUAL_SS
           | SPI_CR_TXFIFO_RST | SPI_CR_RXFIFO_RST
           | SPI_CR_MASTER_INHIBIT;
    SPI_SSR = 0xFF;
}

static void flash_read(uint32_t addr, uint8_t *dst, uint32_t len)
{
    SPI_SSR = 0xFE;

    SPI_CR |= SPI_CR_TXFIFO_RST | SPI_CR_RXFIFO_RST;
    SPI_CR |= SPI_CR_MASTER_INHIBIT;

    /* Send READ command + 3-byte address */
    SPI_DTR = CMD_READ;
    SPI_DTR = (addr >> 16) & 0xFF;
    SPI_DTR = (addr >> 8) & 0xFF;
    SPI_DTR = addr & 0xFF;

    SPI_CR &= ~SPI_CR_MASTER_INHIBIT;
    while (!(SPI_SR & SPI_SR_TX_EMPTY));
    SPI_CR |= SPI_CR_MASTER_INHIBIT;

    /* Discard 4 RX bytes (cmd + addr echo) */
    for (int i = 0; i < 4; i++) {
        while (SPI_SR & SPI_SR_RX_EMPTY);
        (void)SPI_DRR;
    }

    /* Read data in 256-byte chunks (SPI FIFO depth) */
    uint32_t pos = 0;
    while (pos < len) {
        uint32_t chunk = len - pos;
        if (chunk > 256) chunk = 256;

        SPI_CR |= SPI_CR_TXFIFO_RST | SPI_CR_RXFIFO_RST;

        for (uint32_t i = 0; i < chunk; i++)
            SPI_DTR = 0x00;

        SPI_CR &= ~SPI_CR_MASTER_INHIBIT;
        while (!(SPI_SR & SPI_SR_TX_EMPTY));
        SPI_CR |= SPI_CR_MASTER_INHIBIT;

        for (uint32_t i = 0; i < chunk; i++) {
            while (SPI_SR & SPI_SR_RX_EMPTY);
            dst[pos + i] = (uint8_t)(SPI_DRR & 0xFF);
        }
        pos += chunk;
    }

    SPI_SSR = 0xFF;
}

static uint32_t flash_read_id(void)
{
    SPI_SSR = 0xFE;
    SPI_CR |= SPI_CR_TXFIFO_RST | SPI_CR_RXFIFO_RST;
    SPI_CR |= SPI_CR_MASTER_INHIBIT;

    SPI_DTR = CMD_RDID;
    SPI_DTR = 0x00;
    SPI_DTR = 0x00;
    SPI_DTR = 0x00;

    SPI_CR &= ~SPI_CR_MASTER_INHIBIT;
    while (!(SPI_SR & SPI_SR_TX_EMPTY));
    SPI_CR |= SPI_CR_MASTER_INHIBIT;

    uint8_t rx[4];
    for (int i = 0; i < 4; i++) {
        while (SPI_SR & SPI_SR_RX_EMPTY);
        rx[i] = (uint8_t)(SPI_DRR & 0xFF);
    }

    SPI_SSR = 0xFF;
    return ((uint32_t)rx[1] << 16) | ((uint32_t)rx[2] << 8) | rx[3];
}

/* ========== Main ========== */

typedef void (*app_entry_t)(void);

int main(void)
{
    uart_init();
    uart_puts("\n== MicroBlaze RISC-V Bootloader ==\n");

    /* --- SPI init & Flash check --- */
    spi_init();

    uint32_t jedec_id = flash_read_id();
    uart_puts("Flash JEDEC ID: ");
    uart_put_hex32(jedec_id);
    uart_puts("\n");

    if (jedec_id == 0x000000 || jedec_id == 0xFFFFFF) {
        uart_puts("ERROR: Flash not detected! Halting.\n");
        while (1);
    }

    /* --- Read boot header (16 bytes) --- */
    boot_header_t hdr;
    flash_read(FLASH_HEADER_OFFSET, (uint8_t *)&hdr, BOOT_HEADER_SIZE);

    uart_puts("Magic:      ");  uart_put_hex32(hdr.magic);      uart_puts("\n");
    uart_puts("App size:   ");  uart_put_hex32(hdr.app_size);   uart_puts("\n");
    uart_puts("Entry addr: ");  uart_put_hex32(hdr.entry_addr); uart_puts("\n");
    uart_puts("CRC32:      ");  uart_put_hex32(hdr.crc32);      uart_puts("\n");

    /* --- Validate header --- */
    if (hdr.magic != BOOT_MAGIC) {
        uart_puts("ERROR: Invalid magic! No valid image. Halting.\n");
        while (1);
    }

    if (hdr.app_size == 0 || hdr.app_size > APP_MAX_SIZE) {
        uart_puts("ERROR: Invalid app size! Halting.\n");
        while (1);
    }

    /* --- Copy app binary (after header) from Flash to SRAM --- */
    uart_puts("Copying app...\n");
    flash_read(FLASH_HEADER_OFFSET + BOOT_HEADER_SIZE,
               (uint8_t *)hdr.entry_addr,
               hdr.app_size);
    uart_puts("Copy complete.\n");

    /* --- Verify CRC32 --- */
    uint32_t calc_crc = crc32((uint8_t *)hdr.entry_addr, hdr.app_size);
    uart_puts("Calc CRC32: ");
    uart_put_hex32(calc_crc);
    uart_puts("\n");

    if (calc_crc != hdr.crc32) {
        uart_puts("ERROR: CRC mismatch! Image corrupted. Halting.\n");
        while (1);
    }

    uart_puts("CRC OK. Jumping to ");
    uart_put_hex32(hdr.entry_addr);
    uart_puts("\n\n");

    /* --- Jump --- */
    app_entry_t app = (app_entry_t)hdr.entry_addr;
    app();

    uart_puts("ERROR: Application returned!\n");
    while (1);
    return 0;
}
