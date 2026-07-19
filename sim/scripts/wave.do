onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider -color "White" "SYSTEM SIGNALS"
add wave -noupdate -color "Gray75" -radix binary /uart_tb_uvm_top/clk
add wave -noupdate -color "Gray75" -radix binary /uart_tb_uvm_top/rst_n

add wave -noupdate -divider -color "Cyan" "APB BUS INTERFACE"
add wave -noupdate -color "Cyan" -radix hexadecimal /uart_tb_uvm_top/apb_vif/PADDR
add wave -noupdate -color "Cyan" -radix binary /uart_tb_uvm_top/apb_vif/PSEL
add wave -noupdate -color "Cyan" -radix binary /uart_tb_uvm_top/apb_vif/PENABLE
add wave -noupdate -color "Cyan" -radix binary /uart_tb_uvm_top/apb_vif/PWRITE
add wave -noupdate -color "Cyan" -radix hexadecimal /uart_tb_uvm_top/apb_vif/PWDATA
add wave -noupdate -color "Cyan" -radix hexadecimal /uart_tb_uvm_top/apb_vif/PRDATA
add wave -noupdate -color "Cyan" -radix binary /uart_tb_uvm_top/apb_vif/PREADY
add wave -noupdate -color "Red" -radix binary /uart_tb_uvm_top/apb_vif/PSLVERR

add wave -noupdate -divider -color "Pink" "UART SERIAL PORT"
add wave -noupdate -color "Pink" -radix binary /uart_tb_uvm_top/serial_vif/tx_serial
add wave -noupdate -color "Pink" -radix binary /uart_tb_uvm_top/serial_vif/rx_serial

add wave -noupdate -divider -color "Orange" "DUT CONTROLS & PARSING"
add wave -noupdate -color "Orange" -radix ascii /uart_tb_uvm_top/u_dut/data_size_ctrl
add wave -noupdate -color "Orange" -radix ascii /uart_tb_uvm_top/u_dut/parity_ctrl
add wave -noupdate -color "Orange" -radix ascii /uart_tb_uvm_top/u_dut/stop_bits_ctrl
add wave -noupdate -color "Orange" -radix decimal /uart_tb_uvm_top/u_dut/baud_div

add wave -noupdate -divider -color "Yellow" "REGISTERS INTERNAL STATE"
add wave -noupdate -color "Yellow" -radix hexadecimal /uart_tb_uvm_top/u_dut/u_reg_file/cfg_reg
add wave -noupdate -color "Yellow" -radix hexadecimal /uart_tb_uvm_top/u_dut/u_reg_file/baud_div_reg
add wave -noupdate -color "Yellow" -radix binary /uart_tb_uvm_top/u_dut/u_reg_file/rx_valid_status
add wave -noupdate -color "Yellow" -radix binary /uart_tb_uvm_top/u_dut/u_reg_file/dor_reg
add wave -noupdate -color "Yellow" -radix hexadecimal /uart_tb_uvm_top/u_dut/u_reg_file/intr_raw_reg
add wave -noupdate -color "Yellow" -radix hexadecimal /uart_tb_uvm_top/u_dut/u_reg_file/intr_en_reg
add wave -noupdate -color "Yellow" -radix hexadecimal /uart_tb_uvm_top/u_dut/u_reg_file/intr_mask_reg

add wave -noupdate -divider -color "Red" "INTERRUPT LINES"
add wave -noupdate -color "Red" -radix binary /uart_tb_uvm_top/intr_vif/irq_tx_ready
add wave -noupdate -color "Red" -radix binary /uart_tb_uvm_top/intr_vif/irq_tx_done
add wave -noupdate -color "Red" -radix binary /uart_tb_uvm_top/intr_vif/irq_rx_done
add wave -noupdate -color "Red" -radix binary /uart_tb_uvm_top/intr_vif/irq_rx_parity
add wave -noupdate -color "Red" -radix binary /uart_tb_uvm_top/intr_vif/irq_rx_framing
add wave -noupdate -color "Red" -radix binary /uart_tb_uvm_top/intr_vif/irq_rx_overrun
add wave -noupdate -color "Red" -radix binary /uart_tb_uvm_top/intr_vif/irq

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 260
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
WaveRestoreZoom {0 ps} {2 us}
