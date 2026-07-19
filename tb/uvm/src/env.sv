import uvm_pkg::*;
`include "uvm_macros.svh"

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
  uart_reg_predictor predictor;
  reg2apb_adapter   adapter;

  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    apb_agt   = apb_agent::type_id::create("apb_agt", this);
    uart_agt  = uart_agent::type_id::create("uart_agt", this);
    scb       = uart_scoreboard::type_id::create("scb", this);
    predictor = uart_reg_predictor::type_id::create("predictor", this);
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
