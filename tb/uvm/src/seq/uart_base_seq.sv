import uvm_pkg::*;
`include "uvm_macros.svh"

// -----------------------------------------------------------------------------
// Base APB Sequence
// -----------------------------------------------------------------------------
class apb_base_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_base_seq)

  function new(string name = "apb_base_seq");
    super.new(name);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Raw APB Write Sequence
// -----------------------------------------------------------------------------
class apb_write_seq extends apb_base_seq;
  `uvm_object_utils(apb_write_seq)

  rand bit [4:0]  addr;
  rand bit [31:0] data;

  function new(string name = "apb_write_seq");
    super.new(name);
  endfunction

  task body();
    req = apb_seq_item::type_id::create("req");
    start_item(req);
    req.addr  = addr;
    req.write = 1'b1;
    req.wdata = data;
    finish_item(req);
  endtask
endclass

// -----------------------------------------------------------------------------
// Raw APB Read Sequence
// -----------------------------------------------------------------------------
class apb_read_seq extends apb_base_seq;
  `uvm_object_utils(apb_read_seq)

  rand bit [4:0]  addr;
  bit [31:0]      data;

  function new(string name = "apb_read_seq");
    super.new(name);
  endfunction

  task body();
    req = apb_seq_item::type_id::create("req");
    start_item(req);
    req.addr  = addr;
    req.write = 1'b0;
    finish_item(req);
    data = req.rdata;
  endtask
endclass
