class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  apb_agent_config cfg;
  uvm_analysis_port #(apb_seq_item) ap;

  function new(string name = "apb_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq_item trans;

    // Wait for reset release using config helper
    cfg.wait_reset_end();

    forever begin
      trans = apb_seq_item::type_id::create("trans");
      trans.prev_item_delay = 0;
      trans.length = 0;

      // Wait for PSEL to assert while counting idle delay
      while (vif.monitor_cb.PSEL !== 1'b1) begin
        @(vif.monitor_cb);
        trans.prev_item_delay++;
      end

      // Setup phase sampling
      trans.addr  = vif.monitor_cb.PADDR;
      trans.write = vif.monitor_cb.PWRITE;
      trans.length = 1;
      if (trans.write) begin
        trans.wdata = vif.monitor_cb.PWDATA;
      end

      // Transition to Access Phase
      @(vif.monitor_cb);
      trans.length++;

      // Wait for PREADY
      while (vif.monitor_cb.PREADY !== 1'b1) begin
        @(vif.monitor_cb);
        trans.length++;
        
        if (cfg.get_has_checks()) begin
          if (trans.length >= cfg.get_stuck_threshold()) begin
            `uvm_error("APB_STUCK", $sformatf("The APB transfer reached the stuck threshold value of %0d", trans.length))
          end
        end
      end

      // Sample read data and response
      trans.slverr = vif.monitor_cb.PSLVERR;
      if (!trans.write) begin
        trans.rdata = vif.monitor_cb.PRDATA;
      end

      ap.write(trans);
      `uvm_info("APB_MON_TRACK", $sformatf("Time=%0t Monitored item:: %0s", $time, trans.convert2string()), UVM_HIGH)

      // Move past the end of the transaction
      @(vif.monitor_cb);
    end
  endtask

endclass
