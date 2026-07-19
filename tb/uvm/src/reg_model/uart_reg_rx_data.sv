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
