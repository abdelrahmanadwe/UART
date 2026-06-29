// Typedef for UART Sequencer is defined in the package as:
// typedef uvm_sequencer #(uart_seq_item) uart_sequencer;

class uart_agent extends uvm_agent;
  `uvm_component_utils(uart_agent)

  uvm_active_passive_enum is_active = UVM_ACTIVE;

  uart_sequencer sequencer;
  uart_driver    driver;
  uart_monitor   monitor;

  uvm_analysis_port #(uart_seq_item) ap;

  function new(string name = "uart_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    monitor = uart_monitor::type_id::create("monitor", this);
    ap      = new("ap", this);

    if (is_active == UVM_ACTIVE) begin
      sequencer = uvm_sequencer#(uart_seq_item)::type_id::create("sequencer", this);
      driver    = uart_driver::type_id::create("driver", this);
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
