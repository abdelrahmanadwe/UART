`ifndef APB_RESET_HANDLER_SV
`define APB_RESET_HANDLER_SV

interface class apb_reset_handler;
  pure virtual function void handle_reset(uvm_phase phase);
endclass

`endif // APB_RESET_HANDLER_SV
