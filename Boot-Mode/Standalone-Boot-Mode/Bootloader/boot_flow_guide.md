# Cmod A7-35T MicroBlaze RISC-V — Boot Flow 完整指南

## Flash Memory Layout

```
Flash Address    Content                    Size
─────────────────────────────────────────────────
0x000000         Bitstream (含 BRAM 裡的      ~2.1 MB
                 bootloader 初始值)
─────────────────────────────────────────────────
0x300000         Boot Header (16 bytes)       16 B
0x300010         Application Binary           依 app 大小
─────────────────────────────────────────────────
                 剩餘空間 (可放 config 等)
─────────────────────────────────────────────────
```

## Boot Header 格式 (16 bytes, little-endian)

| Offset | Field        | 範例值         | 說明                    |
|--------|-------------|---------------|------------------------|
| 0x00   | magic       | 0xDEADBEEF    | 固定值，驗證 header 有效  |
| 0x04   | app_size    | 0x0000C000    | App binary 大小 (bytes)  |
| 0x08   | entry_addr  | 0x60000000    | 跳轉目標位址             |
| 0x0C   | crc32       | (計算得出)     | App binary 的 CRC32     |

## 上電流程

```
Power On
  │
  ▼
FPGA 硬體自動從 Flash 0x000000 載入 bitstream (~100 ms)
  │  ← Artix-7 SPI boot mode, 不需軟體介入
  ▼
Clocking Wizard 鎖定 100 MHz, proc_sys_reset 釋放 reset
  │
  ▼
MicroBlaze RISC-V 從 0x00000000 (BRAM) 開始執行 bootloader
  │
  ├─ 初始化 UART (115200 baud, 8N1)
  ├─ 初始化 SPI, 讀 JEDEC ID 確認 Flash
  ├─ 讀 Flash 0x300000 的 16-byte header
  ├─ 驗證 magic == 0xDEADBEEF
  ├─ 從 Flash 0x300010 搬 app_size bytes 到 SRAM 0x60000000
  ├─ 計算 CRC32, 比對 header 裡的值
  │
  ▼
跳轉到 0x60000000, Application 開始執行
```

## 檔案清單

| 檔案                    | 用途                              |
|------------------------|----------------------------------|
| `bootloader.c`         | Bootloader 原始碼                  |
| `bootloader_lscript.ld`| Bootloader linker script (BRAM)   |
| `app_lscript.ld`       | Application linker script (SRAM)  |
| `pack_image.py`        | 打包 header + binary 的 Python 腳本|
| `build_and_flash.sh`   | 完整建置與燒錄流程 (首次)            |
| `update_app_only.sh`   | 只更新 app 的快速流程               |

## 操作流程

### 首次完整燒錄 (5 步)

```
Step 1  updatemem
        把 bootloader.elf 合併進 bitstream 的 BRAM
        輸入: top.bit + top.mmi + bootloader.elf
        輸出: download.bit

Step 2  objcopy
        把 app.elf 轉成 raw binary
        輸入: app.elf
        輸出: app.bin

Step 3  pack_image.py
        在 app.bin 前面加 16-byte boot header
        輸入: app.bin
        輸出: app_packed.bin

Step 4  write_cfgmem
        把 bitstream + app 合成一個 .mcs 檔
        輸入: download.bit + app_packed.bin
        輸出: combined.mcs

Step 5  program_flash
        燒進 QSPI Flash
        輸入: combined.mcs
        完成後斷電重開即可自動啟動
```

### 只更新 App (3 步)

當你只改了 application 程式碼, bootloader 不動:

```
Step 1  objcopy        app.elf → app.bin
Step 2  pack_image.py  app.bin → app_packed.bin
Step 3  Flash 只燒 0x300000 區域
```

不需要重跑 synthesis / implementation / updatemem.

## Linker Script 對照

### Bootloader (全部在 BRAM)
```
MEMORY {
    bram : ORIGIN = 0x00000000, LENGTH = 128K
}
.text, .rodata, .data, .bss, .stack → bram
```

### Application (全部在 SRAM)
```
MEMORY {
    sram : ORIGIN = 0x60000000, LENGTH = 512K
}
.text, .rodata, .data, .bss, .heap, .stack → sram
```

## 常見問題

| 現象 | 原因 | 解法 |
|------|------|------|
| DONE LED 不亮 | Bitstream 燒錄失敗 | 重新燒 combined.mcs |
| UART 印 "Flash not detected" | SPI 初始化失敗 | 檢查 Vivado IP 設定 |
| UART 印 "Invalid magic" | Flash 0x300000 沒燒 app | 執行 pack + flash 流程 |
| UART 印 "CRC mismatch" | Flash 寫入不完整 | 重新燒 app 區域 |
| UART 印 "Invalid app size" | Header 損毀 | 重新 pack + flash |
| 跳轉後沒反應 | App entry point 不對 | 檢查 app linker script |
| 中斷不工作 | mtvec 沒設定 | App 初始化時 csrw mtvec |
