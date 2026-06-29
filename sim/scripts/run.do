# Create work library
vlib work

# Compile design and testbench files (relative to repository root)
vlog rtl/common/uart_defs.sv \
     rtl/common/baud_generator.sv \
     rtl/uart_reg_file.sv \
     rtl/rx/uart_rx_deserializer.sv \
     rtl/rx/uart_rx_fsm.sv \
     rtl/rx/uart_rx.sv \
     rtl/tx/uart_tx_fsm.sv \
     rtl/tx/uart_tx_parity.sv \
     rtl/tx/uart_tx_serializer.sv \
     rtl/tx/uart_tx.sv \
     rtl/uart_top.sv \
     rtl/UART.sv \
     tb/tb_uart_top.sv

# Load the simulation with access to internal signals
vsim -voptargs="+acc" tb_uart_top

# Log all signals for debugging
log -r /*

# Add all testbench signals to wave window
add wave -position insertpoint sim:/tb_uart_top/*
add wave -position insertpoint sim:/tb_uart_top/u_dut/*
add wave -position insertpoint sim:/tb_uart_top/u_dut/u_reg_file/*
add wave -position insertpoint sim:/tb_uart_top/u_dut/u_core/*
