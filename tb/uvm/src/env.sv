import uvm_pkg::*;
`include "uvm_macros.svh"

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

// -----------------------------------------------------------------------------
// UVM Environment class definition
// -----------------------------------------------------------------------------
class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  apb_agent         apb_agt;
  uart_agent        uart_agt;
  uart_scoreboard   scb;
  uart_reg_block    reg_model;
  uart_coverage     cov;

  // RAL predictor to update mirror register values
  uvm_reg_predictor #(apb_seq_item) predictor;
  reg2apb_adapter   adapter;

  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    apb_agt   = apb_agent::type_id::create("apb_agt", this);
    uart_agt  = uart_agent::type_id::create("uart_agt", this);
    scb       = uart_scoreboard::type_id::create("scb", this);
    predictor = uvm_reg_predictor#(apb_seq_item)::type_id::create("predictor", this);
    adapter   = reg2apb_adapter::type_id::create("adapter");
    cov       = uart_coverage::type_id::create("cov", this);

    // Retrieve or construct register model
    if (reg_model == null) begin
      reg_model = uart_reg_block::type_id::create("reg_model", this);
      reg_model.build();
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect register model map to APB sequencer if RAL will be used in sequences
    if (reg_model.get_parent() == null) begin
      reg_model.default_map.set_sequencer(apb_agt.sequencer, adapter);
    end

    // Connect RAL Predictor
    predictor.map     = reg_model.default_map;
    predictor.adapter = adapter;
    apb_agt.ap.connect(predictor.bus_in);

    // Pass register model to monitor and scoreboard
    uart_agt.monitor.reg_model = reg_model;
    scb.reg_model              = reg_model;

    // Connect monitors to scoreboard
    apb_agt.ap.connect(scb.apb_export);
    uart_agt.tx_ap.connect(scb.uart_tx_export);
    uart_agt.rx_ap.connect(scb.uart_rx_export);

    // Connect coverage collector
    apb_agt.ap.connect(cov.apb_export);
    cov.reg_model = reg_model;
  endfunction

endclass
