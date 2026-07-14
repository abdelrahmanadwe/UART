import uvm_pkg::*;
`include "uvm_macros.svh"

// Include individual register definitions
`include "uart_reg_cfg.sv"
`include "uart_reg_baud_div.sv"
`include "uart_reg_status.sv"
`include "uart_reg_ris.sv"
`include "uart_reg_ier.sv"
`include "uart_reg_mis.sv"
`include "uart_reg_tx_data.sv"
`include "uart_reg_rx_data.sv"

// -----------------------------------------------------------------------------
// UVM RAL Register Block definition
// -----------------------------------------------------------------------------
class uart_reg_block extends uvm_reg_block;
  `uvm_object_utils(uart_reg_block)

  rand uart_reg_cfg     cfg;
  uart_reg_status       status;
  uart_reg_ris          ris;
  rand uart_reg_ier     ier;
  uart_reg_mis          mis;
  rand uart_reg_tx_data tx_data;
  uart_reg_rx_data      rx_data;
  rand uart_reg_baud_div baud_div;

  uvm_reg_map           default_map;

  function new(string name = "uart_reg_block", int has_coverage = UVM_NO_COVERAGE);
    super.new(name, has_coverage);
  endfunction

  virtual function void build();
    cfg = uart_reg_cfg::type_id::create("cfg");
    cfg.configure(this);
    cfg.build();

    status = uart_reg_status::type_id::create("status");
    status.configure(this);
    status.build();

    ris = uart_reg_ris::type_id::create("ris");
    ris.configure(this);
    ris.build();

    ier = uart_reg_ier::type_id::create("ier");
    ier.configure(this);
    ier.build();

    mis = uart_reg_mis::type_id::create("mis");
    mis.configure(this);
    mis.build();

    tx_data = uart_reg_tx_data::type_id::create("tx_data");
    tx_data.configure(this);
    tx_data.build();

    rx_data = uart_reg_rx_data::type_id::create("rx_data");
    rx_data.configure(this);
    rx_data.build();

    baud_div = uart_reg_baud_div::type_id::create("baud_div");
    baud_div.configure(this);
    baud_div.build();

    // Create address map: default_map
    // name, base_addr, n_bytes, endian
    default_map = create_map("default_map", 'h0, 4, UVM_LITTLE_ENDIAN);
    
    // Add registers to map: reg, offset, access
    default_map.add_reg(cfg,     'h00, "RW");
    default_map.add_reg(status,  'h04, "RO");
    default_map.add_reg(ris,     'h08, "RW"); // W1C registers are set as RW in map to allow writing 1 to clear
    default_map.add_reg(ier,     'h0C, "RW");
    default_map.add_reg(mis,     'h10, "RO");
    default_map.add_reg(tx_data, 'h14, "WO");
    default_map.add_reg(rx_data, 'h18, "RO");
    default_map.add_reg(baud_div, 'h1C, "RW");

    lock_model();
  endfunction
endclass
