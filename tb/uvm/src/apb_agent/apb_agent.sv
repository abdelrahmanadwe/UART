// Typedef for APB Sequencer is defined in the package as:
// typedef uvm_sequencer #(apb_seq_item) apb_sequencer;

class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  uvm_active_passive_enum is_active = UVM_ACTIVE;

  apb_sequencer sequencer;
  apb_driver    driver;
  apb_monitor   monitor;

  uvm_analysis_port #(apb_seq_item) ap;

  function new(string name = "apb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    monitor = apb_monitor::type_id::create("monitor", this);
    ap      = new("ap", this);

    if (is_active == UVM_ACTIVE) begin
      sequencer = uvm_sequencer#(apb_seq_item)::type_id::create("sequencer", this);
      driver    = apb_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    monitor.ap.connect(ap);

    if (is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass
