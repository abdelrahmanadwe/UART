# Include directories for compiler to find headers/includes
+incdir+tb/uvm/src

# Shared RTL defs
rtl/common/uart_defs.sv

# RTL sources
rtl/common/baud_generator.sv
rtl/uart_reg_file.sv
rtl/rx/uart_rx_deserializer.sv
rtl/rx/uart_rx_fsm.sv
rtl/rx/uart_rx.sv
rtl/tx/uart_tx_fsm.sv
rtl/tx/uart_tx_parity.sv
rtl/tx/uart_tx_serializer.sv
rtl/tx/uart_tx.sv
rtl/uart_top.sv
rtl/UART.sv

# UVM Interfaces
tb/uvm/interfaces/apb_if.sv
tb/uvm/interfaces/uart_serial_if.sv
tb/uvm/interfaces/uart_intr_if.sv

# UVM package and top testbench wrapper
tb/uvm/src/uart_uvm_pkg.sv
tb/uvm/uart_tb_uvm_top.sv
