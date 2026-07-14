# APB-Compliant Configurable UART IP

A highly configurable digital Universal Asynchronous Receiver-Transmitter (UART) transceiver IP written in SystemVerilog, featuring a standard **AMBA APB v2.0 Bus Interface** and advanced status/interrupt controls.

---

## Features

- **APB Interface Compliance**: Integrates seamlessly into modern SoC interconnects using standard `PCLK`, `PRESETn`, `PADDR`, `PSEL`, `PENABLE`, `PWRITE`, `PWDATA`, `PREADY`, `PRDATA`, and `PSLVERR`.
- **Hardware-Level Configuration Gating**:
  - Independent **TX Enable** and **RX Enable** controls (default to disabled on reset to prevent accidental transmissions/receptions).
- **Flexible Frame Format**:
  - **Baud Rate**: Programmable (2400, 4800, 9600, 19200, 115200).
  - **Data Size**: Configurable (5, 6, 7, or 8 bits).
  - **Stop Bits**: Configurable (1 or 2 stop bits).
  - **Parity Mode**: Disabled, Even, or Odd.
- **Combined STATUS & Interrupt Controller**:
  - A single consolidated **STATUS** register at `0x04` combines both status flags and raw interrupt sources, mimicking modern microcontroller registers (like STM32 `USART_SR`).
  - Exposes dedicated level and edge-triggered masked interrupt pins:
    - `irq_tx_ready` (Level-sensitive Transmit Buffer Empty)
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
│   ├── register_map.md           # Complete CSR documentation, offsets, and bit fields
│   └── uvm_verification_guide.md # UVM verification environment design guide
├── rtl/
│   ├── common/
│   │   ├── uart_defs.sv          # Shared definitions and config enums
│   │   └── baud_generator.sv     # Configurable baud clock dividers
│   ├── rx/
│   │   ├── uart_rx_deserializer.sv
│   │   ├── uart_rx_fsm.sv
│   │   └── uart_rx.sv            # Complete receiver core
│   ├── tx/
│   │   ├── uart_tx_parity.sv
│   │   ├── uart_tx_serializer.sv
│   │   ├── uart_tx_fsm.sv
│   │   └── uart_tx.sv            # Complete transmitter core
│   ├── uart_top.sv               # Digital core top (TX + RX combined)
│   ├── uart_reg_file.sv          # Control Status Registers (CSRs) & APB bridge
│   └── UART.sv                   # Top-level wrapper (APB + Digital Top)
├── tb/
│   └── uvm/                      # Complete UVM 1.1d verification testbench
│       ├── interfaces/           # SystemVerilog interfaces (apb_if, uart_serial_if, uart_intr_if)
│       ├── src/                  # UVM package source files (env, agents, sequences, scoreboard)
│       └── uart_tb_uvm_top.sv    # Top-level testbench wrapper
├── sim/                          # Simulation outputs, logs, and compile listfiles
├── clean.sh                      # Utility script to clean compile databases and simulation logs
├── run_uvm_cli.sh                # Script to run UVM tests in Command-Line mode
├── run_uvm_gui.sh                # Script to run UVM tests in Graphic GUI mode (opens waves)
├── run_uvm_regression.sh         # Script to run all UVM tests, merge coverage, and report results
└── README.md                     # This file
```

---

## Register Map Summary

Base address offsets:
- `0x00` — **CFG** (Configuration Register, reset value `10'h18`)
- `0x04` — **STATUS** (Consolidated status and raw interrupt flags, W1C/RO, reset value `32'h10`)
- `0x08` — **IER** (Interrupt Enable Register, RW, reset value `32'h0`)
- `0x0C` — **DATA** (Shared Transmit/Receive Data Register, Mix, reset value `32'h0`)
- `0x10` — **BAUD_DIV** (Baud rate divisor register, RW, reset value `16'd163`)
- `0x14` to `0x1C` — **Reserved / Unmapped** (Triggers APB `PSLVERR` bus error on access)

For detailed descriptions of registers and bit maps, refer to [docs/register_map.md](file:///mnt/Local_Disk1/My_GitHub/Digital_Projects/UART/docs/register_map.md).

---

## Verification & Simulation

The IP is fully verified using an industry-standard **UVM 1.1d Verification Environment** with code and functional coverage merged and analyzed.

### Run Regression & Coverage:
To compile the design, run all test scenarios, merge the coverage databases, and generate a unified coverage report, run:
```bash
./run_uvm_regression.sh
```
This script executes the following test suite:
1. `uart_reg_access_test`: Verifies register read/write, default reset values, and illegal register address access error logging.
2. `uart_loopback_test`: Verifies back-to-back APB character write, transmission status flags, loopback to RX, and scoreboard checks.
3. `uart_overrun_test`: Injects overlapping serial bytes to verify Data Overrun (DOR) hardware flags and automatic clearing behaviors.
4. `uart_rand_test`: Applies 90 iterations of fully randomized configurations (data size, stop bits, parity, speeds) to verify legal transmission correctness.
5. `uart_illegal_rand_test`: Exercises boundary conditions, illegal baud divisor = 0, invalid configurations, framing errors, parity errors, and unmapped register PSLVERR assertions.

### Run Single UVM Test in CLI:
```bash
./run_uvm_cli.sh <test_name> [verbosity]
# Example:
./run_uvm_cli.sh uart_rand_test UVM_MEDIUM
```

### Run UVM Test in GUI Mode:
To inspect waveforms, open the Questasim GUI, and load signals, run:
```bash
./run_uvm_gui.sh <test_name> [verbosity]
# Example:
./run_uvm_gui.sh uart_loopback_test
```

### Verification Highlights:
- **Scoreboard Interrupt Counter:** The scoreboard (`uart_scoreboard`) hooks into `uart_intr_if` to count active enabled writes to `TX_DATA` and verify that they match the exact count of rising edges on the `irq_tx_done` interrupt pin at the end of the simulation.
- **Interrupt SVA Assertion:** A concurrent SystemVerilog Assertion inside the `uart_intr_if` interface validates that whenever any individual interrupt flag is raised, the main top-level `irq` pin must also be raised on the clock cycle.
- **Coverage Collection:** Independent covergroups cover configuration settings, status flag combinations, and raw status interrupt transitions to achieve **100.00%** functional coverage.
