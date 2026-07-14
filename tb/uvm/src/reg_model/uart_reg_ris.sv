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
