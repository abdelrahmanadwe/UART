`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

import uart_uvm_pkg::*;

module uart_tb_uvm_top;

  // Clocks and Reset
  logic clk;
  logic rst_n;

  // Force package linking to register components in UVM factory
  uart_base_test dummy_test;

  // Clock Generation (50MHz)
  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end

  // Reset Generation
  initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
  end

  // Instantiate Virtual Interfaces
  apb_if          apb_vif (clk, rst_n);
  uart_serial_if  serial_vif ();
  uart_intr_if    intr_vif (clk, rst_n);

  // Instantiate DUT (Top wrapper with APB interface)
  UART u_dut (
    .PCLK           (clk),
    .PRESETn        (rst_n),
    .PADDR          (apb_vif.PADDR),
    .PSEL           (apb_vif.PSEL),
    .PENABLE        (apb_vif.PENABLE),
    .PWRITE         (apb_vif.PWRITE),
    .PWDATA         (apb_vif.PWDATA),
    .PREADY         (apb_vif.PREADY),
    .PRDATA         (apb_vif.PRDATA),
    .PSLVERR        (apb_vif.PSLVERR),
    .tx_serial      (serial_vif.tx_serial),
    .rx_serial      (serial_vif.rx_serial),
    .irq_tx_ready   (intr_vif.irq_tx_ready),
    .irq_tx_done    (intr_vif.irq_tx_done),
    .irq_rx_done    (intr_vif.irq_rx_done),
    .irq_rx_parity  (intr_vif.irq_rx_parity),
    .irq_rx_framing (intr_vif.irq_rx_framing),
    .irq_rx_overrun (intr_vif.irq_rx_overrun),
    .irq            (intr_vif.irq)
  );

  initial begin
    // Store virtual interfaces in Config DB
    uvm_config_db#(virtual apb_if)::set(null, "*", "vif", apb_vif);
    uvm_config_db#(virtual apb_if)::set(null, "*", "vif_apb", apb_vif);
    uvm_config_db#(virtual uart_serial_if)::set(null, "*", "vif", serial_vif);
    uvm_config_db#(virtual uart_intr_if)::set(null, "*", "vif", intr_vif);

    // Force registration of tests in the UVM factory by referencing their type_ids
    begin
      string dummy_name;
      dummy_name = uart_base_test::type_id::get().get_type_name();
      dummy_name = uart_reg_access_test::type_id::get().get_type_name();
      dummy_name = uart_loopback_test::type_id::get().get_type_name();
      dummy_name = uart_overrun_test::type_id::get().get_type_name();
      dummy_name = uart_rand_test::type_id::get().get_type_name();
      dummy_name = uart_illegal_rand_test::type_id::get().get_type_name();
    end

    // Run the UVM Test
    run_test();
  end



endmodule
