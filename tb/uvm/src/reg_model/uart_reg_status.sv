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
