import uvm_pkg::*;
`include "uvm_macros.svh"

// -----------------------------------------------------------------------------
// CFG Register Definition
// -----------------------------------------------------------------------------
class uart_reg_cfg extends uvm_reg;
  `uvm_object_utils(uart_reg_cfg)

  rand uvm_reg_field data_size;
  rand uvm_reg_field parity;
  rand uvm_reg_field stop_bits;
  rand uvm_reg_field tx_enable;
  rand uvm_reg_field rx_enable;

  function new(string name = "uart_reg_cfg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    data_size = uvm_reg_field::type_id::create("data_size");
    parity    = uvm_reg_field::type_id::create("parity");
    stop_bits = uvm_reg_field::type_id::create("stop_bits");
    tx_enable = uvm_reg_field::type_id::create("tx_enable");
    rx_enable = uvm_reg_field::type_id::create("rx_enable");

    // configure(parent, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible)
    data_size.configure(this, 2, 3, "RW", 0, 2'b11,  1, 1, 0);
    parity.configure   (this, 2, 5, "RW", 0, 2'b00,  1, 1, 0);
    stop_bits.configure(this, 1, 7, "RW", 0, 1'b0,   1, 1, 0);
    tx_enable.configure(this, 1, 8, "RW", 0, 1'b0,   1, 1, 0);
    rx_enable.configure(this, 1, 9, "RW", 0, 1'b0,   1, 1, 0);
  endfunction
endclass

// -----------------------------------------------------------------------------
// BAUD_DIV Register Definition
// -----------------------------------------------------------------------------
class uart_reg_baud_div extends uvm_reg;
  `uvm_object_utils(uart_reg_baud_div)

  rand uvm_reg_field divisor;

  function new(string name = "uart_reg_baud_div");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    divisor = uvm_reg_field::type_id::create("divisor");
    divisor.configure(this, 16, 0, "RW", 0, 16'd163, 1, 1, 0);
  endfunction
endclass

// -----------------------------------------------------------------------------
// STATUS Register Definition
// -----------------------------------------------------------------------------
class uart_reg_status extends uvm_reg;
  `uvm_object_utils(uart_reg_status)

  uvm_reg_field tx_ready;
  uvm_reg_field rx_valid;
  uvm_reg_field dor;

  function new(string name = "uart_reg_status");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    tx_ready = uvm_reg_field::type_id::create("tx_ready");
    rx_valid = uvm_reg_field::type_id::create("rx_valid");
    dor      = uvm_reg_field::type_id::create("dor");

    tx_ready.configure(this, 1, 0, "RO", 1, 1'b1, 1, 0, 0);
    rx_valid.configure(this, 1, 1, "RO", 1, 1'b0, 1, 0, 0);
    dor.configure     (this, 1, 2, "RO", 1, 1'b0, 1, 0, 0);
  endfunction
endclass

// -----------------------------------------------------------------------------
// RIS Register Definition
// -----------------------------------------------------------------------------
class uart_reg_ris extends uvm_reg;
  `uvm_object_utils(uart_reg_ris)

  uvm_reg_field tx_done;
  uvm_reg_field parity_error;
  uvm_reg_field framing_error;
  uvm_reg_field rx_done;
  uvm_reg_field tx_ready;
  uvm_reg_field overrun_error;

  function new(string name = "uart_reg_ris");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    tx_done       = uvm_reg_field::type_id::create("tx_done");
    parity_error  = uvm_reg_field::type_id::create("parity_error");
    framing_error = uvm_reg_field::type_id::create("framing_error");
    rx_done       = uvm_reg_field::type_id::create("rx_done");
    tx_ready      = uvm_reg_field::type_id::create("tx_ready");
    overrun_error = uvm_reg_field::type_id::create("overrun_error");

    tx_done.configure      (this, 1, 0, "W1C", 1, 1'b0, 1, 0, 0);
    parity_error.configure (this, 1, 1, "W1C", 1, 1'b0, 1, 0, 0);
    framing_error.configure(this, 1, 2, "W1C", 1, 1'b0, 1, 0, 0);
    rx_done.configure      (this, 1, 3, "W1C", 1, 1'b0, 1, 0, 0);
    tx_ready.configure     (this, 1, 4, "RO",  1, 1'b1, 1, 0, 0);
    overrun_error.configure(this, 1, 5, "W1C", 1, 1'b0, 1, 0, 0);
  endfunction
endclass

// -----------------------------------------------------------------------------
// IER Register Definition
// -----------------------------------------------------------------------------
class uart_reg_ier extends uvm_reg;
  `uvm_object_utils(uart_reg_ier)

  rand uvm_reg_field tx_done_ie;
  rand uvm_reg_field parity_error_ie;
  rand uvm_reg_field framing_error_ie;
  rand uvm_reg_field rx_done_ie;
  rand uvm_reg_field tx_ready_ie;
  rand uvm_reg_field overrun_error_ie;

  function new(string name = "uart_reg_ier");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    tx_done_ie       = uvm_reg_field::type_id::create("tx_done_ie");
    parity_error_ie  = uvm_reg_field::type_id::create("parity_error_ie");
    framing_error_ie = uvm_reg_field::type_id::create("framing_error_ie");
    rx_done_ie       = uvm_reg_field::type_id::create("rx_done_ie");
    tx_ready_ie      = uvm_reg_field::type_id::create("tx_ready_ie");
    overrun_error_ie = uvm_reg_field::type_id::create("overrun_error_ie");

    tx_done_ie.configure      (this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
    parity_error_ie.configure (this, 1, 1, "RW", 0, 1'b0, 1, 1, 0);
    framing_error_ie.configure(this, 1, 2, "RW", 0, 1'b0, 1, 1, 0);
    rx_done_ie.configure      (this, 1, 3, "RW", 0, 1'b0, 1, 1, 0);
    tx_ready_ie.configure     (this, 1, 4, "RW", 0, 1'b0, 1, 1, 0);
    overrun_error_ie.configure(this, 1, 5, "RW", 0, 1'b0, 1, 1, 0);
  endfunction
endclass

// -----------------------------------------------------------------------------
// MIS Register Definition
// -----------------------------------------------------------------------------
class uart_reg_mis extends uvm_reg;
  `uvm_object_utils(uart_reg_mis)

  uvm_reg_field tx_done_mis;
  uvm_reg_field parity_error_mis;
  uvm_reg_field framing_error_mis;
  uvm_reg_field rx_done_mis;
  uvm_reg_field tx_ready_mis;
  uvm_reg_field overrun_error_mis;

  function new(string name = "uart_reg_mis");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    tx_done_mis       = uvm_reg_field::type_id::create("tx_done_mis");
    parity_error_mis  = uvm_reg_field::type_id::create("parity_error_mis");
    framing_error_mis = uvm_reg_field::type_id::create("framing_error_mis");
    rx_done_mis       = uvm_reg_field::type_id::create("rx_done_mis");
    tx_ready_mis      = uvm_reg_field::type_id::create("tx_ready_mis");
    overrun_error_mis = uvm_reg_field::type_id::create("overrun_error_mis");

    tx_done_mis.configure      (this, 1, 0, "RO", 1, 1'b0, 1, 0, 0);
    parity_error_mis.configure (this, 1, 1, "RO", 1, 1'b0, 1, 0, 0);
    framing_error_mis.configure(this, 1, 2, "RO", 1, 1'b0, 1, 0, 0);
    rx_done_mis.configure      (this, 1, 3, "RO", 1, 1'b0, 1, 0, 0);
    tx_ready_mis.configure     (this, 1, 4, "RO", 1, 1'b0, 1, 0, 0);
    overrun_error_mis.configure(this, 1, 5, "RO", 1, 1'b0, 1, 0, 0);
  endfunction
endclass

// -----------------------------------------------------------------------------
// TX_DATA Register Definition
// -----------------------------------------------------------------------------
class uart_reg_tx_data extends uvm_reg;
  `uvm_object_utils(uart_reg_tx_data)

  rand uvm_reg_field data;

  function new(string name = "uart_reg_tx_data");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    data = uvm_reg_field::type_id::create("data");
    data.configure(this, 8, 0, "WO", 0, 8'h00, 1, 1, 0);
  endfunction
endclass

// -----------------------------------------------------------------------------
// RX_DATA Register Definition
// -----------------------------------------------------------------------------
class uart_reg_rx_data extends uvm_reg;
  `uvm_object_utils(uart_reg_rx_data)

  uvm_reg_field data;

  function new(string name = "uart_reg_rx_data");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    data = uvm_reg_field::type_id::create("data");
    data.configure(this, 8, 0, "RO", 1, 8'h00, 1, 0, 0);
  endfunction
endclass

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
