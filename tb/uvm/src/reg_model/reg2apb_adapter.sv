// -----------------------------------------------------------------------------
// APB Register Adapter definition
// -----------------------------------------------------------------------------
class reg2apb_adapter extends uvm_reg_adapter;
  `uvm_object_utils(reg2apb_adapter)

  function new(string name = "reg2apb_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 0;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_seq_item apb = apb_seq_item::type_id::create("apb");
    apb.addr  = rw.addr[4:0];
    apb.write = (rw.kind == UVM_WRITE);
    if (apb.write) begin
      apb.wdata = rw.data;
    end
    return apb;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    apb_seq_item apb;
    if (!$cast(apb, bus_item)) begin
      `uvm_fatal("APB_ADAPT", "Failed to cast bus_item to apb_seq_item")
      return;
    end
    rw.kind = apb.write ? UVM_WRITE : UVM_READ;
    rw.addr = apb.addr;
    rw.data = apb.write ? apb.wdata : apb.rdata;
    rw.status = apb.slverr ? UVM_NOT_OK : UVM_IS_OK;
  endfunction
endclass
