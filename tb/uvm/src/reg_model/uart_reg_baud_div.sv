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
