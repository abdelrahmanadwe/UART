// -----------------------------------------------------------------------------
// Custom RAL Predictor class definition
// -----------------------------------------------------------------------------
class uart_reg_predictor extends uvm_reg_predictor #(apb_seq_item);
  `uvm_component_utils(uart_reg_predictor)

  function new(string name = "uart_reg_predictor", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
