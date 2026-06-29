class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_seq_item) ap;

  function new(string name = "apb_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("APB_MON", "Failed to get virtual interface vif from config DB")
    end
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq_item trans;

    @(posedge vif.PRESETn);

    forever begin
      @(vif.monitor_cb);
      // Sample transaction at the end of setup phase/access phase
      if (vif.monitor_cb.PSEL && vif.monitor_cb.PENABLE) begin
        // Wait for PREADY
        while (vif.monitor_cb.PREADY !== 1'b1) begin
          @(vif.monitor_cb);
        end

        // Transaction complete, sample it
        trans = apb_seq_item::type_id::create("trans");
        trans.addr   = vif.monitor_cb.PADDR;
        trans.write  = vif.monitor_cb.PWRITE;
        trans.slverr = vif.monitor_cb.PSLVERR;
        if (vif.monitor_cb.PWRITE) begin
          trans.wdata = vif.monitor_cb.PWDATA;
        end else begin
          trans.rdata = vif.monitor_cb.PRDATA;
        end

        ap.write(trans);
      end
    end
  endtask

endclass
