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
