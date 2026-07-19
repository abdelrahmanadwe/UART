import uvm_pkg::*;
`include "uvm_macros.svh"

// -----------------------------------------------------------------------------
// Base Test Class
// -----------------------------------------------------------------------------
class uart_base_test extends uvm_test;
  `uvm_component_utils(uart_base_test)

  uart_env env;
  apb_agent_config apb_cfg;
  uart_agent_config uart_cfg;

  function new(string name = "uart_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    virtual apb_if vif_apb;
    virtual uart_serial_if vif_uart;

    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);

    apb_cfg = apb_agent_config::type_id::create("apb_cfg");
    uart_cfg = uart_agent_config::type_id::create("uart_cfg");

    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif_apb", vif_apb)) begin
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif_apb)) begin
        `uvm_fatal("BASE_TEST", "Failed to get virtual apb_if from config DB")
      end
    end

    if (!uvm_config_db#(virtual uart_serial_if)::get(this, "", "vif", vif_uart)) begin
      `uvm_fatal("BASE_TEST", "Failed to get virtual uart_serial_if from config DB")
    end

    apb_cfg.set_vif(vif_apb);
    apb_cfg.set_is_active(UVM_ACTIVE);

    uart_cfg.vif = vif_uart;
    uart_cfg.vif_apb = vif_apb;
    uart_cfg.is_active = UVM_ACTIVE;

    uvm_config_db#(apb_agent_config)::set(this, "env.apb_agt", "cfg", apb_cfg);
    uvm_config_db#(uart_agent_config)::set(this, "env.uart_agt", "cfg", uart_cfg);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    // Overridden by specific tests
  endtask
endclass

// -----------------------------------------------------------------------------
// Register Access Verification Test
// -----------------------------------------------------------------------------
class uart_reg_access_test extends uart_base_test;
  `uvm_component_utils(uart_reg_access_test)

  function new(string name = "uart_reg_access_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_reg_access_vseq vseq = uart_reg_access_vseq::type_id::create("vseq");
    phase.raise_objection(this);
    
    // Assign handles to virtual sequence
    vseq.apb_seqr   = env.apb_agt.sequencer;
    vseq.uart_seqr  = env.uart_agt.sequencer;
    vseq.reg_model  = env.reg_model;
    
    vseq.start(null);
    phase.drop_objection(this);
  endtask
endclass

// -----------------------------------------------------------------------------
// Loopback Functionality Verification Test
// -----------------------------------------------------------------------------
class uart_loopback_test extends uart_base_test;
  `uvm_component_utils(uart_loopback_test)

  function new(string name = "uart_loopback_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_loopback_vseq vseq = uart_loopback_vseq::type_id::create("vseq");
    phase.raise_objection(this);
    
    vseq.apb_seqr   = env.apb_agt.sequencer;
    vseq.uart_seqr  = env.uart_agt.sequencer;
    vseq.reg_model  = env.reg_model;
    
    vseq.start(null);
    #10us; // Drain time to allow final check_phase processing
    phase.drop_objection(this);
  endtask
endclass

// -----------------------------------------------------------------------------
// Data OverRun (DOR) Verification Test
// -----------------------------------------------------------------------------
class uart_overrun_test extends uart_base_test;
  `uvm_component_utils(uart_overrun_test)

  function new(string name = "uart_overrun_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_overrun_vseq vseq = uart_overrun_vseq::type_id::create("vseq");
    phase.raise_objection(this);
    
    vseq.apb_seqr   = env.apb_agt.sequencer;
    vseq.uart_seqr  = env.uart_agt.sequencer;
    vseq.reg_model  = env.reg_model;
    
    vseq.start(null);
    #10us; // Drain time
    phase.drop_objection(this);
  endtask
endclass

// -----------------------------------------------------------------------------
// Legal Randomized Verification Test
// -----------------------------------------------------------------------------
class uart_rand_test extends uart_base_test;
  `uvm_component_utils(uart_rand_test)

  function new(string name = "uart_rand_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_rand_vseq vseq = uart_rand_vseq::type_id::create("vseq");
    phase.raise_objection(this);
    
    vseq.apb_seqr   = env.apb_agt.sequencer;
    vseq.uart_seqr  = env.uart_agt.sequencer;
    vseq.reg_model  = env.reg_model;
    
    vseq.start(null);
    #10us; // Drain time
    phase.drop_objection(this);
  endtask
endclass

// -----------------------------------------------------------------------------
// Illegal/Corner-Case Randomized Verification Test
// -----------------------------------------------------------------------------
class uart_illegal_rand_test extends uart_base_test;
  `uvm_component_utils(uart_illegal_rand_test)

  function new(string name = "uart_illegal_rand_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_illegal_rand_vseq vseq = uart_illegal_rand_vseq::type_id::create("vseq");
    phase.raise_objection(this);
    
    vseq.apb_seqr   = env.apb_agt.sequencer;
    vseq.uart_seqr  = env.uart_agt.sequencer;
    vseq.reg_model  = env.reg_model;
    
    vseq.start(null);
    #10us; // Drain time
    phase.drop_objection(this);
  endtask
endclass
