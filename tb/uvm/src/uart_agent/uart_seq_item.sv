typedef enum bit [1:0] {
  ERR_NONE,
  ERR_PARITY,
  ERR_FRAMING
} uart_error_e;

class uart_seq_item extends uvm_sequence_item;

  rand bit [7:0]        data;
  rand data_size_e      data_size;
  rand parity_ctrl_e    parity_ctrl;
  rand stop_bits_e      stop_bits;
  rand baud_rate_e      baud_rate;
  rand uart_error_e     error_type;

  `uvm_object_utils_begin(uart_seq_item)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_enum(data_size_e, data_size, UVM_ALL_ON)
    `uvm_field_enum(parity_ctrl_e, parity_ctrl, UVM_ALL_ON)
    `uvm_field_enum(stop_bits_e, stop_bits, UVM_ALL_ON)
    `uvm_field_enum(baud_rate_e, baud_rate, UVM_ALL_ON)
    `uvm_field_enum(uart_error_e, error_type, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_seq_item");
    super.new(name);
    // Default standard configuration
    data_size   = DATA_8_BITS;
    parity_ctrl = PARITY_NONE;
    stop_bits   = STOP_1_BIT;
    baud_rate   = BAUD_19200;
    error_type  = ERR_NONE;
  endfunction

endclass
