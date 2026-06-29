# APB-Compliant Configurable UART IP

A highly configurable digital Universal Asynchronous Receiver-Transmitter (UART) transceiver IP written in SystemVerilog, featuring a standard **AMBA APB v2.0 Bus Interface** and advanced status/interrupt controls.

---

## Features

- **APB Interface Compliance**: Integrates seamlessly into modern SoC interconnects using standard PCLK, PRESETn, PADDR, PSEL, PENABLE, PWRITE, PWDATA, PREADY, PRDATA, and PSLVERR.
- **Hardware-Level Configuration Gating**:
  - Independent **TX Enable** and **RX Enable** controls (default to disabled on reset to prevent accidental transmissions/receptions).
- **Flexible Frame Format**:
  - **Baud Rate**: Programmable (2400, 4800, 9600, 19200, 115200).
  - **Data Size**: Configurable (5, 6, 7, or 8 bits).
  - **Stop Bits**: Configurable (1 or 2 stop bits).
  - **Parity Mode**: Disabled, Even, or Odd (standard AVR Atmega Table 64 mapping).
- **Advanced Interrupt Controller**:
  - Exposes dedicated level and edge-triggered masked interrupt pins:
    - `irq_tx_ready` (Level-sensitive Transmit Buffer Empty / UDRE)
    - `irq_tx_done` (Edge-triggered Transmit Complete)
    - `irq_rx_done` (Edge-triggered Receive Complete)
    - `irq_rx_parity` (Parity Error)
    - `irq_rx_framing` (Framing Error)
    - `irq_rx_overrun` (Data Overrun)
  - Unified `irq` logical OR pin for single-line CPU interrupt processing.
- **Robust Hardware Protections**:
  - Automatically gates writes to `TX_DATA` if `tx_enable == 0`.
  - Immediate `tx_ready` status deassertion on `TX_DATA` write prevents race conditions and overwriting of buffer data during back-to-back transmissions.
  - **Data Overrun (DOR) Detection**: Sets status flag and triggers interrupt if a new frame arrives before the previous one is read from the buffer.

---

## Directory Structure

```text
UART/
├── docs/
│   └── register_map.md       # Complete CSR documentation, offsets, and bit fields
├── rtl/
│   ├── common/
│   │   ├── uart_defs.sv      # Shared definitions and config enums
│   │   └── baud_generator.sv # Configurable baud clock dividers
│   ├── rx/
│   │   ├── uart_rx_deserializer.sv
│   │   ├── uart_rx_fsm.sv
│   │   └── uart_rx.sv        # Complete receiver core
│   ├── tx/
│   │   ├── uart_tx_parity.sv
│   │   ├── uart_tx_serializer.sv
│   │   ├── uart_tx_fsm.sv
│   │   └── uart_tx.sv        # Complete transmitter core
│   ├── uart_top.sv           # Digital core top (TX + RX combined)
│   ├── uart_reg_file.sv      # Control Status Registers (CSRs) & APB bridge
│   └── UART.sv               # Top-level wrapper (APB + Digital Top)
├── tb/
│   └── tb_uart_top.sv        # Comprehensive testbench with 6 verification test cases
└── README.md                 # This file
```

---

## Register Map Summary

Base address offsets:
- `0x00` — **CFG** (Configuration Register, reset value `10'h1B`)
- `0x04` — **STATUS** (Status Register, Read-Only, reset value `32'h1`)
- `0x08` — **RIS** (Raw Interrupt Status, W1C/RO, reset value `32'h10`)
- `0x0C` — **IER** (Interrupt Enable Register, RW, reset value `32'h0`)
- `0x10` — **MIS** (Masked Interrupt Status, Read-Only, reset value `32'h0`)
- `0x14` — **TX_DATA** (Transmit Data, Write-Only)
- `0x18` — **RX_DATA** (Receive Data, Read-Only, auto-clears status flags on read)

For detailed descriptions of registers and bit maps, refer to [docs/register_map.md](file:///mnt/Local_Disk1/My_GitHub/Digital_Projects/UART/docs/register_map.md).

---

## Verification & Simulation

A comprehensive self-checking testbench is located in `tb/tb_uart_top.sv`. It verifies:
1. Gating of TX/RX enables.
2. Standard configurations (8-N-1 at 19.2K).
3. Frame configs (5-bit, Odd parity, 2 stop bits).
4. Edge interrupts and W1C capability.
5. Level-sensitive `tx_ready` interrupt behavior.
6. Back-to-back writes without buffer data loss.
7. High-speed transmission (115.2K).
8. Data Overrun (DOR) logic and automatic flag clearing.

### To Run Simulation (Direct Testbench):
Using **QuestaSim / ModelSim**:
```bash
# Run direct testbench in CLI mode
./run_tb_cli.sh

# Run direct testbench in GUI mode (opens Waveforms)
./run_tb_gui.sh
```

---

## Advanced UVM Verification Environment

We have built a complete, industry-standard **UVM Verification Environment** to thoroughly verify register mappings, loopback paths, and data overrun behaviors.

For detailed UVM block diagrams, architecture details, and verification plans, please refer to the **[UVM Verification Environment Guide](file:///mnt/Local_Disk1/My_GitHub/Digital_Projects/UART/docs/uvm_verification_guide.md)**.

### To Run UVM Tests:
Make sure you have QuestaSim/ModelSim with UVM support sourced, and run:

```bash
# Run Loopback Test (CLI mode)
./run_uvm_cli.sh uart_loopback_test

# Run Register Access Test (CLI mode)
./run_uvm_cli.sh uart_reg_access_test

# Run Data Overrun (DOR) Test (CLI mode)
./run_uvm_cli.sh uart_overrun_test

# Run in GUI mode with waveforms
./run_uvm_gui.sh [test_name]
```

