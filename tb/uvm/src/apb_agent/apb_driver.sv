class apb_driver extends uvm_driver #(apb_seq_item) implements apb_reset_handler;
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;
  apb_agent_config cfg;

  protected process process_drive_transactions;

  function new(string name = "apb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      fork
        begin
          cfg.wait_reset_end();
          drive_transactions();
          disable fork;
        end
      join
    end
  endtask

  protected virtual task drive_transactions();
    // Initialize signals
    vif.cb.PSEL    <= 1'b0;
    vif.cb.PENABLE <= 1'b0;
    vif.cb.PWRITE  <= 1'b0;
    vif.cb.PADDR   <= 5'h0;
    vif.cb.PWDATA  <= 32'h0;

    fork
      begin
        process_drive_transactions = process::self();
        forever begin
          seq_item_port.get_next_item(req);
          drive_transfer(req);
          seq_item_port.item_done();
        end
      end
    join
  endtask

  virtual function void handle_reset(uvm_phase phase);
    if (process_drive_transactions != null) begin
      process_drive_transactions.kill();
      process_drive_transactions = null;
    end

    // Re-initialize signals
    vif.cb.PSEL    <= 1'b0;
    vif.cb.PENABLE <= 1'b0;
    vif.cb.PWRITE  <= 1'b0;
    vif.cb.PADDR   <= 5'h0;
    vif.cb.PWDATA  <= 32'h0;
  endfunction

  task drive_transfer(apb_seq_item item);
    // Align with clocking block first
    @(vif.cb);

    // Pre-drive delay
    for (int i = 0; i < item.pre_drive_delay; i++) begin
      @(vif.cb);
    end

    // Setup Phase
    vif.cb.PADDR   <= item.addr;
    vif.cb.PWRITE  <= item.write;
    vif.cb.PSEL    <= 1'b1;
    vif.cb.PENABLE <= 1'b0;
    if (item.write) begin
      vif.cb.PWDATA <= item.wdata;
    end

    // Access Phase
    @(vif.cb);
    vif.cb.PENABLE <= 1'b1;

    // Wait for PREADY (evaluates on subsequent clock edges)
    @(vif.cb);
    while (vif.cb.PREADY !== 1'b1) begin
      @(vif.cb);
    end

    // Read data at the end of the access phase
    if (!item.write) begin
      item.rdata = vif.cb.PRDATA;
    end
    item.slverr = vif.cb.PSLVERR;

    `uvm_info("APB_DRV_TRACK", $sformatf("Time=%0t PADDR=%h PWRITE=%b PWDATA=%h PRDATA=%h PREADY=%b PSLVERR=%b",
              $time, item.addr, item.write, item.wdata, item.rdata, vif.cb.PREADY, item.slverr), UVM_HIGH)

    // Clean up
    vif.cb.PSEL    <= 1'b0;
    vif.cb.PENABLE <= 1'b0;
    vif.cb.PWRITE  <= 1'b0;
    vif.cb.PADDR   <= 5'h0;
    vif.cb.PWDATA  <= 32'h0;

    // Post-drive delay
    for (int i = 0; i < item.post_drive_delay; i++) begin
      @(vif.cb);
    end
  endtask

endclass
