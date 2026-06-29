# Shared definitions
rtl/common/uart_defs.sv

# Helper blocks
rtl/common/baud_generator.sv
rtl/uart_reg_file.sv

# Receiver sub-modules
rtl/rx/uart_rx_deserializer.sv
rtl/rx/uart_rx_fsm.sv
rtl/rx/uart_rx.sv

# Transmitter sub-modules
rtl/tx/uart_tx_fsm.sv
rtl/tx/uart_tx_parity.sv
rtl/tx/uart_tx_serializer.sv
rtl/tx/uart_tx.sv

# Top Wrapper modules
rtl/uart_top.sv
rtl/UART.sv

# Testbench
tb/tb_uart_top.sv
