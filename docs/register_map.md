# UART Register Map

This document describes the memory-mapped register interface of the UART peripheral, accessible via a standard **AMBA APB3/APB4** bus.

- **Base Address**: Determined by the SoC address decoder.
- **Address Bus Width**: 5-bit byte-aligned offsets (`PADDR[4:0]`).
- **Data Bus Width**: 32-bit (`PWDATA[31:0]` / `PRDATA[31:0]`).
- **Wait States**: Zero (PREADY is always high).
- **Error Reporting**: `PSLVERR` is asserted during the Access Phase if the address is invalid.

---

## Register Summary

| Address | Register | Access | Reset Value | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x00` | [CFG](#0x00--cfg--configuration-register) | RW | `0x0000_0018` | Line configuration & enables (data size, parity, stop bits, enables). |
| `0x04` | [STATUS](#0x04--status--status-and-raw-interrupt-register) | RW1C / RO | `0x0000_0010` | Consolidated status and raw interrupt event flags. Bit 4 is level-sensitive (RO), others are W1C. |
| `0x08` | [IER](#0x08--ier--interrupt-enable-register) | RW | `0x0000_0000` | Interrupt enable masks. |
| `0x0C` | [DATA](#0x0c--data--data-register) | Mix (WO/RO) | `0x0000_0000` | Shared Data Register. Writes go to TX buffer, reads come from RX buffer (auto-clears status flags). |
| `0x10` | [BAUD_DIV](#0x10--baud_div--baud-rate-divisor-register) | RW | `0x0000_00A3` | Baud rate divisor value. |
| `0x14` to `0x1C` | — | — | — | **Reserved / Unmapped** (Triggers `PSLVERR` on access). |

> [!NOTE]
> **Access Types**: **RW** = Read/Write, **RO** = Read Only, **WO** = Write Only, **RW1C** = Read / Write-1-to-Clear.

---

## Register Details

### `0x00` — CFG (Configuration Register)

Configures the UART line parameters and enables/disables transmission/reception.

| Bits | Field | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[2:0]` | — | — | `0` | Reserved. |
| `[4:3]` | `data_size` | RW | `2'b11` | Number of data bits per frame. See encoding table below. |
| `[6:5]` | `parity` | RW | `2'b00` | Parity mode selection. See encoding table below (Atmega Standard). |
| `[7]` | `stop_bits` | RW | `1'b0` | Number of stop bits. `0` = 1 stop bit, `1` = 2 stop bits. |
| `[8]` | `tx_enable` | RW | `1'b0` | Transmitter Enable. `0` = Disabled, `1` = Enabled. |
| `[9]` | `rx_enable` | RW | `1'b0` | Receiver Enable. `0` = Disabled, `1` = Enabled. |
| `[31:10]` | — | — | `0` | Reserved. |

> [!IMPORTANT]
> **TX & RX Enables default to `0` after reset**. You must configure the line settings and set bits [9:8] to `1` before attempting any transmission or reception.

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

### `0x04` — STATUS (Status and Raw Interrupt Register)

Consolidated status register reflecting both the active hardware states and raw interrupt events (similar to STM32 `USART_SR`).

| Bits | Field | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[0]` | `tx_done` | RW1C | `0` | Set when transmitter completes sending a frame (including stop bit). Cleared by writing `1`. |
| `[1]` | `parity_error` | RW1C | `0` | Set when receiver detects a parity mismatch. Cleared by writing `1`. |
| `[2]` | `framing_error` | RW1C | `0` | Set when receiver does not detect a valid stop bit. Cleared by writing `1`. |
| `[3]` | `rx_done` | RW1C | `0` | Set when receiver completes receiving a byte. **Auto-clears** when `RX_DATA` (`0x10`) is read, or by writing `1`. |
| `[4]` | `tx_ready` | RO | `1` | **Level-sensitive**. `1` when transmit buffer is empty and ready for a new byte via `TX_DATA`. |
| `[5]` | `overrun_error` | RW1C | `0` | Set when receiver buffer overruns. **Auto-clears** when `RX_DATA` (`0x10`) is read, or by writing `1`. |
| `[31:6]` | — | — | `0` | Reserved. |

> [!TIP]
> Software should poll `STATUS.tx_ready` (bit 4) before writing to `TX_DATA`. Writes to `TX_DATA` while `tx_ready == 0` or while `tx_enable == 0` are silently ignored.

---

### `0x08` — IER (Interrupt Enable Register)

Controls which status event flags inside `STATUS` are allowed to trigger masked interrupt outputs and the global `irq` pin.

| Bits | Field | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[0]` | `tx_done_ie` | RW | `0` | `1` = Enable `tx_done` interrupt. |
| `[1]` | `parity_error_ie` | RW | `0` | `1` = Enable `parity_error` interrupt. |
| `[2]` | `framing_error_ie` | RW | `0` | `1` = Enable `framing_error` interrupt. |
| `[3]` | `rx_done_ie` | RW | `0` | `1` = Enable `rx_done` interrupt. |
| `[4]` | `tx_ready_ie` | RW | `0` | `1` = Enable `tx_ready` interrupt. |
| `[5]` | `overrun_error_ie` | RW | `0` | `1` = Enable `overrun_error` interrupt. |
| `[31:6]` | — | — | `0` | Reserved. |

The individual masked interrupt statuses (computed combinationally as `intr_mask = STATUS & IER`) are routed directly to output pins at the top level for system-level routing, but are not readable via a separate APB register:

| Masked Interrupt | Output Pin |
| :--- | :--- |
| `tx_done` enabled | `irq_tx_done` |
| `parity_error` enabled | `irq_rx_parity` |
| `framing_error` enabled | `irq_rx_framing` |
| `rx_done` enabled | `irq_rx_done` |
| `tx_ready` enabled | `irq_tx_ready` |
| `overrun_error` enabled | `irq_rx_overrun` |

The global `irq` output pin is the logical OR of all active enabled interrupts: **`irq = |(STATUS & IER)`**.

---

### `0x0C` — DATA (Data Register)

Shared register address for data transmit (TDR) and receive (RDR) operations.
* **Writes** to this register go to the Transmit Data Register (WO). Writing a byte initiates a UART transmission.
* **Reads** from this register return the last received byte from the Receive Data Register (RO). Reading this register automatically clears `STATUS.rx_done` and `STATUS.overrun_error`.

| Bits | Field | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[7:0]` | `data` | WO/RO | `0x00` | Transmit write data / Receive read data. Only the lower `data_size` bits are active. |
| `[31:8]` | — | — | `0` | Reserved. |

> [!WARNING]
> Writes to the transmit register are **silently ignored** if `STATUS.tx_ready == 0` (i.e. if the TX buffer is full or `tx_enable == 0`).

---

### `0x10` — BAUD_DIV (Baud Rate Divisor Register)

Read/Write register configuring the baud rate division factor. This register is frequency-independent and works across any clock rate.

| Bits | Field | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[15:0]` | `divisor` | RW | `16'd163` | Baud rate divisor value. Sets the 16x oversampling clock generator. |
| `[31:16]` | — | — | `0` | Reserved. |

#### Baud Rate Calculation Equation
The software driver calculates the divisor value using the following equation:
$$\text{divisor} = \frac{F_{\text{CLK}}}{\text{Baud Rate} \times 16}$$

#### Configuration Examples ($F_{\text{CLK}} = 50\text{ MHz}$)
| Target Baud Rate | Calculation | Divisor (Decimal) | Divisor (Hex) |
| :--- | :--- | :--- | :--- |
| **2400** | $\frac{50,000,000}{2400 \times 16} = 1302.08$ | `1302` | `0x0516` |
| **4800** | $\frac{50,000,000}{4800 \times 16} = 651.04$ | `651` | `0x028B` |
| **9600** | $\frac{50,000,000}{9600 \times 16} = 325.52$ | `326` | `0x0146` |
| **19200** | $\frac{50,000,000}{19200 \times 16} = 162.76$ | `163` | `0x00A3` |
| **115200** | $\frac{50,000,000}{115200 \times 16} = 27.12$ | `27` | `0x001B` |

---

## Memory Map Visual

```
 Offset   Register
 ──────   ─────────────────────────────────
 0x00     ┌───────────────────────────────┐
          │         CFG (RW)              │
 0x04     ├───────────────────────────────┤
          │       STATUS (Mix)            │
 0x08     ├───────────────────────────────┤
          │         IER (RW)              │
 0x0C     ├───────────────────────────────┤
          │         DATA (Mix)            │
 0x10     ├───────────────────────────────┤
          │      BAUD_DIV (RW)            │
          └───────────────────────────────┘
```

---

## Typical Software Usage

### Initialization (e.g. 115200 Baud at 50 MHz clock)
```c
// 1. Configure divisor for 115200 Baud: 50,000,000 / (115200 * 16) = 27
UART->BAUD_DIV = 27;

// 2. Configure line parameters (8-bit data, no parity, 1 stop bit) and enable TX/RX
UART->CFG = 0x318; 
```

### Transmitting a Byte (Polling)
```c
// 1. Wait until transmitter is ready (STATUS bit 4 is tx_ready)
while (!(UART->STATUS & 0x10));

// 2. Write data to DATA
UART->DATA = byte_to_send;
```

### Receiving a Byte (Polling)
```c
// 1. Wait until a byte is available (STATUS bit 3 is rx_done)
while (!(UART->STATUS & 0x08));

// 2. Read data from DATA (auto-clears STATUS.rx_done and STATUS.overrun_error)
uint8_t received = UART->DATA & 0xFF;
```

### Receiving a Byte (Interrupt-Driven)
```c
// Setup: Enable rx_done interrupt
UART->IER = 0x8; // Enable bit 3 (rx_done)

// ISR:
void UART_IRQHandler(void) {
    uint32_t status = UART->STATUS;
    uint32_t ier = UART->IER;
    
    // Check if rx_done interrupt fired (both STATUS.rx_done and IER.rx_done_ie are high)
    if ((status & 0x08) && (ier & 0x08)) {
        uint8_t data = UART->DATA; // Reading DATA auto-clears STATUS.rx_done
        // Process data...
    }
    
    // Clear any other active interrupts (e.g. parity_error, framing_error, overrun_error, tx_done)
    UART->STATUS = status; // W1C all active flags
}
```
