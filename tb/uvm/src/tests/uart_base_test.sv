import uvm_pkg::*;
`include "uvm_macros.svh"

// -----------------------------------------------------------------------------
// Base Test Class
// -----------------------------------------------------------------------------
class uart_base_test extends uvm_test;
  `uvm_component_utils(uart_base_test)

  uart_env env;

  function new(string name = "uart_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);
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
