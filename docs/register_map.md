# UART Register Map

This document describes the memory-mapped register interface of the UART peripheral, accessible via a standard **AMBA APB3/APB4** bus.

- **Base Address**: Determined by the SoC address decoder.
- **Address Bus Width**: 5-bit byte-aligned offsets (`PADDR[4:0]`).
- **Data Bus Width**: 32-bit (`PWDATA[31:0]` / `PRDATA[31:0]`).
- **Wait States**: Zero (PREADY is always high).
- **Error Reporting**: `PSLVERR` is asserted during the Access Phase if the address is invalid.

---

## Register Summary

| Offset | Name | Access | Reset Value | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x00` | [CFG](#0x00--cfg--configuration-register) | RW | `0x0000_001B` | Line configuration & enables (baud, data size, parity, stop bits, enables). |
| `0x04` | [STATUS](#0x04--status--status-register) | RO | `0x0000_0001` | TX ready and RX data available status flags. |
| `0x08` | [RIS](#0x08--ris--raw-interrupt-status) | RW1C / RO | `0x0000_0010` | Raw (unmasked) interrupt event flags. Bit 4 is level-sensitive (RO), bits [3:0] are W1C. |
| `0x0C` | [IER](#0x0c--ier--interrupt-enable-register) | RW | `0x0000_0000` | Interrupt enable masks. |
| `0x10` | [MIS](#0x10--mis--masked-interrupt-status) | RO | `0x0000_0000` | Masked interrupt status (RIS AND IER). |
| `0x14` | [TX_DATA](#0x14--tx_data--transmit-data-register) | WO | `0x0000_0000` | Data byte to transmit. |
| `0x18` | [RX_DATA](#0x18--rx_data--receive-data-register) | RO | `0x0000_0000` | Last received data byte. Reading clears `STATUS.rx_valid` and `RIS.rx_done`. |

> [!NOTE]
> **Access Types**: **RW** = Read/Write, **RO** = Read Only, **WO** = Write Only, **RW1C** = Read / Write-1-to-Clear.

---

## Register Details

### `0x00` — CFG (Configuration Register)

Configures the UART line parameters and enables/disables transmission/reception.

| Bits | Field | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[2:0]` | `baud_rate` | RW | `3'b011` | Baud rate selection. See encoding table below. |
| `[4:3]` | `data_size` | RW | `2'b11` | Number of data bits per frame. See encoding table below. |
| `[6:5]` | `parity` | RW | `2'b00` | Parity mode selection. See encoding table below (Atmega Standard). |
| `[7]` | `stop_bits` | RW | `1'b0` | Number of stop bits. `0` = 1 stop bit, `1` = 2 stop bits. |
| `[8]` | `tx_enable` | RW | `1'b0` | Transmitter Enable. `0` = Disabled, `1` = Enabled. |
| `[9]` | `rx_enable` | RW | `1'b0` | Receiver Enable. `0` = Disabled, `1` = Enabled. |
| `[31:10]` | — | — | `0` | Reserved. |

> [!IMPORTANT]
> **TX & RX Enables default to `0` after reset**. You must configure the line settings and set bits [9:8] to `1` before attempting any transmission or reception.

#### Baud Rate Encoding (`baud_rate`)

| Value | Baud Rate |
| :--- | :--- |
| `3'b000` | 2400 |
| `3'b001` | 4800 |
| `3'b010` | 9600 |
| `3'b011` | 19200 (Default) |
| `3'b100` | 115200 |
| `3'b101`–`3'b111` | Reserved (defaults to 19200) |

#### Data Size Encoding (`data_size`)

| Value | Data Bits |
| :--- | :--- |
| `2'b00` | 5 bits |
| `2'b01` | 6 bits |
| `2'b10` | 7 bits |
| `2'b11` | 8 bits (Default) |

#### Parity Encoding (`parity`)

| Value | Parity Mode |
| :--- | :--- |
| `2'b00` | None / Disabled (Default) |
| `2'b01` | Reserved |
| `2'b10` | Enabled, Even Parity |
| `2'b11` | Enabled, Odd Parity |

---

### `0x04` — STATUS (Status Register)

Read-only register reflecting the current hardware status of the transmitter and receiver.

| Bits | Field | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[0]` | `tx_ready` | RO | `1` | `1` = Transmitter buffer is empty and ready to accept a new byte via `TX_DATA`. `0` = Transmit register is full/busy. |
| `[1]` | `rx_valid` | RO | `0` | `1` = A new byte has been received and is available in `RX_DATA`. Auto-clears when `RX_DATA` is read. |
| `[2]` | `dor` | RO | `0` | `1` = Data OverRun. Set when a new byte is received before the previous one was read. Auto-clears when `RX_DATA` is read. |
| `[31:3]` | — | — | `0` | Reserved. |

> [!TIP]
> Software should poll `STATUS.tx_ready` (or wait for the `tx_ready` interrupt) before writing to `TX_DATA`. Writes to `TX_DATA` while `tx_ready == 0` or while `tx_enable == 0` are silently ignored.

---

### `0x08` — RIS (Raw Interrupt Status)

Latches hardware interrupt events regardless of the interrupt enable mask.

| Bits | Field | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[0]` | `tx_done` | RW1C | `0` | Set when the transmitter completes sending a byte (including stop bit). Cleared by writing `1`. |
| `[1]` | `parity_error` | RW1C | `0` | Set when the receiver detects a parity mismatch. Cleared by writing `1`. |
| `[2]` | `framing_error` | RW1C | `0` | Set when the receiver does not detect a valid stop bit. Cleared by writing `1`. |
| `[3]` | `rx_done` | RW1C | `0` | Set when the receiver completes receiving a byte. **Auto-clears** when `RX_DATA` (`0x18`) is read, or by writing `1`. |
| `[4]` | `tx_ready` | RO | `1` | **Level-sensitive**. Reflected directly from `STATUS.tx_ready` (1 when TX buffer is empty). |
| `[5]` | `overrun_error` | RW1C | `0` | Set when receiver buffer overruns. **Auto-clears** when `RX_DATA` (`0x18`) is read, or by writing `1`. |
| `[31:6]` | — | — | `0` | Reserved. |

---

### `0x0C` — IER (Interrupt Enable Register)

Controls which raw interrupt events are allowed to propagate to the masked interrupt status (`MIS`) and ultimately to the global `irq` output pin.

| Bits | Field | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[0]` | `tx_done_ie` | RW | `0` | `1` = Enable `tx_done` interrupt. |
| `[1]` | `parity_error_ie` | RW | `0` | `1` = Enable `parity_error` interrupt. |
| `[2]` | `framing_error_ie` | RW | `0` | `1` = Enable `framing_error` interrupt. |
| `[3]` | `rx_done_ie` | RW | `0` | `1` = Enable `rx_done` interrupt. |
| `[4]` | `tx_ready_ie` | RW | `0` | `1` = Enable `tx_ready` interrupt. |
| `[5]` | `overrun_error_ie` | RW | `0` | `1` = Enable `overrun_error` interrupt. |
| `[31:6]` | — | — | `0` | Reserved. |

---

### `0x10` — MIS (Masked Interrupt Status)

Read-only register showing the currently active, unmasked interrupts. Computed combinationally as: **`MIS = RIS & IER`**.

| Bits | Field | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[0]` | `tx_done_mis` | RO | `0` | `1` if `tx_done` is both set (RIS) and enabled (IER). |
| `[1]` | `parity_error_mis` | RO | `0` | `1` if `parity_error` is both set and enabled. |
| `[2]` | `framing_error_mis` | RO | `0` | `1` if `framing_error` is both set and enabled. |
| `[3]` | `rx_done_mis` | RO | `0` | `1` if `rx_done` is both set (RIS) and enabled (IER). |
| `[4]` | `tx_ready_mis` | RO | `0` | `1` if `tx_ready` is both active (RIS) and enabled (IER). |
| `[5]` | `overrun_error_mis` | RO | `0` | `1` if `overrun_error` is both set (RIS) and enabled (IER). |
| `[31:6]` | — | — | `0` | Reserved. |

Each bit of MIS is also routed to a dedicated output pin at the top level:

| MIS Bit | Output Pin |
| :--- | :--- |
| `[0]` | `irq_tx_done` |
| `[1]` | `irq_rx_parity` |
| `[2]` | `irq_rx_framing` |
| `[3]` | `irq_rx_done` |
| `[4]` | `irq_tx_ready` |
| `[5]` | `irq_rx_overrun` |

The global `irq` output is the logical OR of all MIS bits: **`irq = |MIS`**.

---

### `0x14` — TX_DATA (Transmit Data Register)

Write-only register. Writing a byte to this register initiates a UART transmission.

| Bits | Field | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[7:0]` | `tx_data` | WO | `0x00` | The data byte to transmit. Only the lower `data_size` bits are shifted out on the serial line. |
| `[31:8]` | — | — | `0` | Reserved (ignored on write). |

> [!WARNING]
> Writes to `TX_DATA` are **silently ignored** if `STATUS.tx_ready == 0` (i.e. if the TX buffer is full or `tx_enable == 0`).

---

### `0x18` — RX_DATA (Receive Data Register)

Read-only register holding the last received byte.

| Bits | Field | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[7:0]` | `rx_data` | RO | `0x00` | The last received data byte. Only the lower `data_size` bits are valid. |
| `[31:8]` | — | — | `0` | Reserved. |

---

## Memory Map Visual

```
 Offset   Register
 ──────   ─────────────────────────────────
 0x00     ┌───────────────────────────────┐
          │         CFG (RW)              │
 0x04     ├───────────────────────────────┤
          │       STATUS (RO)             │
 0x08     ├───────────────────────────────┤
          │        RIS (Mix)              │
 0x0C     ├───────────────────────────────┤
          │        IER (RW)               │
 0x10     ├───────────────────────────────┤
          │        MIS (RO)               │
 0x14     ├───────────────────────────────┤
          │      TX_DATA (WO)             │
 0x18     ├───────────────────────────────┤
          │      RX_DATA (RO)             │
          └───────────────────────────────┘
 0x1C     Unmapped (PSLVERR on access)
```

---

## Typical Software Usage

### Transmitting a Byte
```c
// 1. Wait until transmitter is ready
while (!(UART->STATUS & 0x1));

// 2. Write data to TX_DATA
UART->TX_DATA = byte_to_send;
```

### Receiving a Byte (Polling)
```c
// 1. Wait until a byte is available
while (!(UART->STATUS & 0x2));

// 2. Read data from RX_DATA (auto-clears rx_valid and rx_done)
uint8_t received = UART->RX_DATA & 0xFF;
```

### Receiving a Byte (Interrupt-Driven)
```c
// Setup: Enable rx_done interrupt
UART->IER = 0x8; // Enable bit 3 (rx_done)

// ISR:
void UART_IRQHandler(void) {
    if (UART->MIS & 0x8) {
        uint8_t data = UART->RX_DATA; // Auto-clears RIS.rx_done
        // Process data...
    }
    // Clear any remaining events
    UART->RIS = UART->RIS; // W1C all active flags
}
```
