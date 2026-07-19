class apb_seq_item extends uvm_sequence_item;

  rand bit [4:0]  addr;
  rand bit        write; // 1 = write, 0 = read
  rand bit [31:0] wdata;
  bit [31:0]      rdata;
  bit             slverr;

  // Driver delay controls
  rand int unsigned pre_drive_delay;
  rand int unsigned post_drive_delay;

  // Monitor-populated timing details
  int unsigned length;
  int unsigned prev_item_delay;

  constraint c_addr_align {
    addr[1:0] == 2'b00; // aligned to 4-byte boundaries
  }

  constraint c_pre_drive_delay_default {
    soft pre_drive_delay <= 5;
  }

  constraint c_post_drive_delay_default {
    soft post_drive_delay <= 5;
  }

  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(addr,   UVM_ALL_ON)
    `uvm_field_int(write,  UVM_ALL_ON)
    `uvm_field_int(wdata,  UVM_ALL_ON)
    `uvm_field_int(rdata,  UVM_ALL_ON)
    `uvm_field_int(slverr, UVM_ALL_ON)
    `uvm_field_int(pre_drive_delay,  UVM_ALL_ON)
    `uvm_field_int(post_drive_delay, UVM_ALL_ON)
    `uvm_field_int(length,           UVM_ALL_ON)
    `uvm_field_int(prev_item_delay,  UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  virtual function string convert2string();
    string s = $sformatf("dir: %s, addr: %h", (write ? "WRITE" : "READ"), addr);
    if (write) begin
      s = $sformatf("%s, wdata: %h", s, wdata);
    end else begin
      s = $sformatf("%s, rdata: %h", s, rdata);
    end
    s = $sformatf("%s, slverr: %b, pre_delay: %0d, post_delay: %0d, length: %0d, prev_delay: %0d",
                  s, slverr, pre_drive_delay, post_drive_delay, length, prev_item_delay);
    return s;
  endfunction

endclass
