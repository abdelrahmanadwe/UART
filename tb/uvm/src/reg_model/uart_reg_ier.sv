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
