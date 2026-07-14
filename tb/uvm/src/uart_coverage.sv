class uart_coverage extends uvm_component;
  `uvm_component_utils(uart_coverage)

  uvm_analysis_imp #(apb_seq_item, uart_coverage) apb_export;
  uart_reg_block reg_model;

  // Variables to hold values for sampling
  bit [1:0]  data_size;
  bit [1:0]  parity;
  bit        stop_bits;
  bit [15:0] baud_div;

  bit        tx_ready;
  bit        rx_valid;
  bit        dor;

  bit        tx_done;
  bit        parity_error;
  bit        framing_error;
  bit        rx_done;
  bit        overrun_error;

  covergroup cg_cfg;
    option.per_instance = 1;
    cp_data_size: coverpoint data_size {
      bins size_5 = {2'b00};
      bins size_6 = {2'b01};
      bins size_7 = {2'b10};
      bins size_8 = {2'b11};
    }
    cp_parity: coverpoint parity {
      bins parity_none = {2'b00};
      bins parity_rsvd = {2'b01}; // reserved/unused parity mode
      bins parity_even = {2'b10};
      bins parity_odd  = {2'b11};
    }
    cp_stop_bits: coverpoint stop_bits {
      bins stop_1 = {1'b0};
      bins stop_2 = {1'b1};
    }
    cp_baud_div: coverpoint baud_div {
      bins div_zero  = {16'h0}; // Illegal divisor
      bins div_small = {[16'd1:16'd9]};
      bins div_legal = {[16'd10:16'd500]};
    }
    cross_cfg: cross cp_data_size, cp_parity, cp_stop_bits;
  endgroup

  covergroup cg_status;
    option.per_instance = 1;
    cp_tx_ready: coverpoint tx_ready;
    cp_rx_valid: coverpoint rx_valid;
    cp_dor:      coverpoint dor;
  endgroup

  covergroup cg_interrupts;
    option.per_instance = 1;
    cp_intr_tx_done:      coverpoint tx_done;
    cp_intr_parity_err:   coverpoint parity_error;
    cp_intr_framing_err:  coverpoint framing_error;
    cp_intr_rx_done:      coverpoint rx_done;
    cp_intr_tx_ready:     coverpoint tx_ready;
    cp_intr_overrun_err:  coverpoint overrun_error;
  endgroup

  function new(string name = "uart_coverage", uvm_component parent = null);
    super.new(name, parent);
    cg_cfg = new();
    cg_status = new();
    cg_interrupts = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb_export = new("apb_export", this);
  endfunction

  function void write(apb_seq_item trans);
    if (reg_model != null) begin
      // Sample CFG
      if (trans.write && trans.addr == 5'h00) begin
        data_size = trans.wdata[4:3];
        parity    = trans.wdata[6:5];
        stop_bits = trans.wdata[7];
        cg_cfg.sample();
      end

      // Sample BAUD_DIV
      if (trans.write && trans.addr == 5'h14) begin
        baud_div = trans.wdata[15:0];
        cg_cfg.sample();
      end
      
      // Sample STATUS (combines status flags and raw interrupt flags)
      if (trans.addr == 5'h04) begin
        bit [31:0] status_val = trans.write ? trans.wdata : trans.rdata;
        
        // Status bits for cg_status
        tx_ready = status_val[4];
        rx_valid = status_val[3];
        dor      = status_val[5];
        cg_status.sample();

        // Interrupt bits for cg_interrupts
        tx_done       = status_val[0];
        parity_error  = status_val[1];
        framing_error = status_val[2];
        rx_done       = status_val[3];
        tx_ready      = status_val[4];
        overrun_error = status_val[5];
        cg_interrupts.sample();
      end
    end
  endfunction
endclass
