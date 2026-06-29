class apb_seq_item extends uvm_sequence_item;

  rand bit [4:0]  addr;
  rand bit        write; // 1 = write, 0 = read
  rand bit [31:0] wdata;
  bit [31:0]      rdata;
  bit             slverr;

  constraint c_addr_align {
    addr[1:0] == 2'b00; // aligned to 4-byte boundaries
  }

  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(addr,   UVM_ALL_ON)
    `uvm_field_int(write,  UVM_ALL_ON)
    `uvm_field_int(wdata,  UVM_ALL_ON)
    `uvm_field_int(rdata,  UVM_ALL_ON)
    `uvm_field_int(slverr, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

endclass
