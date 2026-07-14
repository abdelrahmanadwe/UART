import uvm_pkg::*;
`include "uvm_macros.svh"

// -----------------------------------------------------------------------------
// Base UART Serial Sequence
// -----------------------------------------------------------------------------
class uart_base_seq extends uvm_sequence #(uart_seq_item);
  `uvm_object_utils(uart_base_seq)

  function new(string name = "uart_base_seq");
    super.new(name);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Standard UART Serial Transmission Sequence
// -----------------------------------------------------------------------------
class uart_send_frame_seq extends uart_base_seq;
  `uvm_object_utils(uart_send_frame_seq)

  rand bit [7:0]        data;
  rand data_size_e      data_size;
  rand parity_ctrl_e    parity_ctrl;
  rand stop_bits_e      stop_bits;
  rand bit [15:0]       baud_div;
  rand uart_error_e     error_type;

  function new(string name = "uart_send_frame_seq");
    super.new(name);
    // Defaults matching standard configuration
    data_size   = DATA_8_BITS;
    parity_ctrl = PARITY_NONE;
    stop_bits   = STOP_1_BIT;
    baud_div    = 16'd163;
    error_type  = ERR_NONE;
  endfunction

  task body();
    req = uart_seq_item::type_id::create("req");
    start_item(req);
    req.data        = data;
    req.data_size   = data_size;
    req.parity_ctrl = parity_ctrl;
    req.stop_bits   = stop_bits;
    req.baud_div    = baud_div;
    req.error_type  = error_type;
    finish_item(req);
  endtask
endclass
