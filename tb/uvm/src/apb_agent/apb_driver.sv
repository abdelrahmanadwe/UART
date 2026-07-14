class apb_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name = "apb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    // Initialize signals
    vif.cb.PSEL    <= 1'b0;
    vif.cb.PENABLE <= 1'b0;
    vif.cb.PWRITE  <= 1'b0;
    vif.cb.PADDR   <= 5'h0;
    vif.cb.PWDATA  <= 32'h0;

    // Wait for reset release
    @(posedge vif.PRESETn);
    
    forever begin
      seq_item_port.get_next_item(req);
      drive_transfer(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_transfer(apb_seq_item item);
    // Setup Phase
    @(vif.cb);
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
  endtask

endclass
