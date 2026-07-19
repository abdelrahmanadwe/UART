// Typedef for UART Sequencer is defined in the package as:
// typedef uvm_sequencer #(uart_seq_item) uart_sequencer;

class uart_agent extends uvm_agent;
  `uvm_component_utils(uart_agent)

  uart_agent_config cfg;
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  uart_sequencer sequencer;
  uart_driver    driver;
  uart_monitor   monitor;

  uvm_analysis_port #(uart_seq_item) tx_ap;
  uvm_analysis_port #(uart_seq_item) rx_ap;

  function new(string name = "uart_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(uart_agent_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("UART_AGT", "Failed to get uart_agent_config from config DB")
    end
    is_active = cfg.is_active;

    monitor = uart_monitor::type_id::create("monitor", this);
    tx_ap   = new("tx_ap", this);
    rx_ap   = new("rx_ap", this);

    if (is_active == UVM_ACTIVE) begin
      sequencer = uvm_sequencer#(uart_seq_item)::type_id::create("sequencer", this);
      driver    = uart_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    monitor.vif     = cfg.vif;
    monitor.vif_apb = cfg.vif_apb;
    monitor.tx_ap.connect(tx_ap);
    monitor.rx_ap.connect(rx_ap);

    if (is_active == UVM_ACTIVE) begin
      driver.vif     = cfg.vif;
      driver.vif_apb = cfg.vif_apb;
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass
