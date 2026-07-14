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
