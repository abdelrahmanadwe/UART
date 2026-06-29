onerror {resume}
quietly WaveActivateNextPane {} 0

# Divider: APB Interface
add wave -noupdate -divider -height 32 "APB Bus Interface"
add wave -noupdate -color {Cyan} -itemcolor {Cyan} /tb_uart_top/clk
add wave -noupdate -color {Cyan} -itemcolor {Cyan} /tb_uart_top/rst_n
add wave -noupdate -color {Yellow} -itemcolor {Yellow} -radix hex /tb_uart_top/PADDR
add wave -noupdate -color {Yellow} -itemcolor {Yellow} /tb_uart_top/PSEL
add wave -noupdate -color {Yellow} -itemcolor {Yellow} /tb_uart_top/PENABLE
add wave -noupdate -color {Yellow} -itemcolor {Yellow} /tb_uart_top/PWRITE
add wave -noupdate -color {Orange} -itemcolor {Orange} -radix hex /tb_uart_top/PWDATA
add wave -noupdate -color {Green} -itemcolor {Green} /tb_uart_top/PREADY
add wave -noupdate -color {Green} -itemcolor {Green} -radix hex /tb_uart_top/PRDATA
add wave -noupdate -color {Red} -itemcolor {Red} /tb_uart_top/PSLVERR

# Divider: Serial Interface
add wave -noupdate -divider -height 32 "Serial Loopback Line"
add wave -noupdate -color {Gold} -itemcolor {Gold} /tb_uart_top/serial_line

# Divider: Interrupts
add wave -noupdate -divider -height 32 "Masked Interrupts"
add wave -noupdate -color {Orange} -itemcolor {Orange} /tb_uart_top/irq_tx_ready
add wave -noupdate -color {Orange} -itemcolor {Orange} /tb_uart_top/irq_tx_done
add wave -noupdate -color {Orange} -itemcolor {Orange} /tb_uart_top/irq_rx_done
add wave -noupdate -color {Orange} -itemcolor {Orange} /tb_uart_top/irq_rx_parity
add wave -noupdate -color {Orange} -itemcolor {Orange} /tb_uart_top/irq_rx_framing
add wave -noupdate -color {Orange} -itemcolor {Orange} /tb_uart_top/irq_rx_overrun
add wave -noupdate -color {Red} -itemcolor {Red} -height 20 /tb_uart_top/irq

# Divider: Configuration Control
add wave -noupdate -divider -height 32 "Control & Configuration"
add wave -noupdate -color {Pink} -itemcolor {Pink} -radix binary /tb_uart_top/u_dut/u_reg_file/cfg_reg
add wave -noupdate -color {Pink} -itemcolor {Pink} /tb_uart_top/u_dut/data_size_ctrl
add wave -noupdate -color {Pink} -itemcolor {Pink} /tb_uart_top/u_dut/parity_ctrl
add wave -noupdate -color {Pink} -itemcolor {Pink} /tb_uart_top/u_dut/stop_bits_ctrl
add wave -noupdate -color {Pink} -itemcolor {Pink} /tb_uart_top/u_dut/baud_rate_ctrl
add wave -noupdate -color {Pink} -itemcolor {Pink} /tb_uart_top/u_dut/tx_enable_ctrl
add wave -noupdate -color {Pink} -itemcolor {Pink} /tb_uart_top/u_dut/rx_enable_ctrl

# Divider: TX Core
add wave -noupdate -divider -height 32 "Transmitter (TX) Core"
add wave -noupdate -color {Violet} -itemcolor {Violet} -radix hex /tb_uart_top/u_dut/u_core/u_tx/P_DATA
add wave -noupdate -color {Violet} -itemcolor {Violet} /tb_uart_top/u_dut/u_core/u_tx/Data_Valid
add wave -noupdate -color {Violet} -itemcolor {Violet} /tb_uart_top/u_dut/u_core/u_tx/ready
add wave -noupdate -color {Violet} -itemcolor {Violet} /tb_uart_top/u_dut/u_core/u_tx/tx_done
add wave -noupdate -color {Violet} -itemcolor {Violet} /tb_uart_top/u_dut/u_core/u_tx/u_fsm/state

# Divider: RX Core
add wave -noupdate -divider -height 32 "Receiver (RX) Core"
add wave -noupdate -color {Lime Green} -itemcolor {Lime Green} -radix hex /tb_uart_top/u_dut/u_core/u_rx/P_DATA
add wave -noupdate -color {Lime Green} -itemcolor {Lime Green} /tb_uart_top/u_dut/u_core/u_rx/Data_Valid
add wave -noupdate -color {Lime Green} -itemcolor {Lime Green} /tb_uart_top/u_dut/u_core/u_rx/parity_error
add wave -noupdate -color {Lime Green} -itemcolor {Lime Green} /tb_uart_top/u_dut/u_core/u_rx/framing_error
add wave -noupdate -color {Lime Green} -itemcolor {Lime Green} /tb_uart_top/u_dut/u_core/u_rx/u_fsm/state

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {3500000 ns}
