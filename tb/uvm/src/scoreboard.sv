import uvm_pkg::*;
`include "uvm_macros.svh"

`uvm_analysis_imp_decl(_apb)
`uvm_analysis_imp_decl(_uart_tx)
`uvm_analysis_imp_decl(_uart_rx)

class uart_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(uart_scoreboard)

  uvm_analysis_imp_apb     #(apb_seq_item,  uart_scoreboard) apb_export;
  uvm_analysis_imp_uart_tx #(uart_seq_item, uart_scoreboard) uart_tx_export;
  uvm_analysis_imp_uart_rx #(uart_seq_item, uart_scoreboard) uart_rx_export;

  // Expected queues
  bit [7:0] tx_expected_q[$];
  bit [7:0] rx_expected_q[$];

  // Handle to UVM Register Model
  uart_reg_block reg_model;

  // Virtual interface handle for interrupts
  virtual uart_intr_if intr_vif;

  // Counters for verifying irq_tx_done interrupt against APB writes
  int tx_write_count = 0;
  int tx_done_intr_count = 0;

  function new(string name = "uart_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb_export     = new("apb_export",     this);
    uart_tx_export = new("uart_tx_export", this);
    uart_rx_export = new("uart_rx_export", this);

    // Retrieve interrupt virtual interface
    if (!uvm_config_db#(virtual uart_intr_if)::get(this, "", "vif", intr_vif)) begin
      `uvm_fatal("SCB_CFG_ERR", "Could not get handle to interrupt virtual interface intr_vif!")
    end
  endfunction

  // Monitor rising edge of irq_tx_done in run_phase
  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge intr_vif.irq_tx_done);
      tx_done_intr_count++;
      `uvm_info("SCB_INTR_CHECK", $sformatf("Detected posedge on irq_tx_done! Counter = %0d", tx_done_intr_count), UVM_MEDIUM)
    end
  endtask

  // APB Transaction Monitor write implementation
  function void write_apb(apb_seq_item trans);
    // TX Data Write
    if (trans.write && trans.addr == 5'h0C) begin
      // Verify tx_enable is active
      bit [31:0] cfg_val = reg_model.cfg.get_mirrored_value();
      bit [31:0] ier_val = reg_model.ier.get_mirrored_value();
      if (cfg_val[8] == 1'b1) begin // tx_enable is bit 8
        `uvm_info("SCB_TX", $sformatf("Expected TX Byte written to APB: %h", trans.wdata[7:0]), UVM_MEDIUM)
        tx_expected_q.push_back(trans.wdata[7:0]);
        // Increment the TX write counter ONLY if the tx_done interrupt is enabled (IER[0] == 1)
        if (ier_val[0] == 1'b1) begin
          tx_write_count++;
          `uvm_info("SCB_INTR_CHECK", $sformatf("Incremented tx_write_count = %0d", tx_write_count), UVM_MEDIUM)
        end
      end
    end

    // RX Data Read
    if (!trans.write && trans.addr == 5'h10) begin
      `uvm_info("SCB_RX", $sformatf("Read RX Byte from APB: %h", trans.rdata[7:0]), UVM_MEDIUM)
      if (rx_expected_q.size() == 0) begin
        `uvm_error("SCB_RX_ERR", $sformatf("Read RX Data %h from APB, but rx_expected_q is empty!", trans.rdata[7:0]))
      end else begin
        bit [7:0] exp_byte = rx_expected_q.pop_front();
        if (trans.rdata[7:0] !== exp_byte) begin
          `uvm_error("SCB_RX_MISMATCH", $sformatf("RX Mismatch! Read %h from APB, Expected %h", trans.rdata[7:0], exp_byte))
        end else begin
          `uvm_info("SCB_RX_MATCH", $sformatf("RX Match! Read %h successfully matched expected %h", trans.rdata[7:0], exp_byte), UVM_MEDIUM)
        end
      end
    end
  endfunction

  // UART TX Monitor write implementation (captures serial frames driven by the DUT's tx_serial line)
  function void write_uart_tx(uart_seq_item trans);
    `uvm_info("SCB_TX", $sformatf("Captured Serial TX Byte: %h", trans.data), UVM_MEDIUM)
    if (tx_expected_q.size() == 0) begin
      `uvm_error("SCB_TX_ERR", $sformatf("Captured Serial TX Byte %h, but tx_expected_q is empty!", trans.data))
    end else begin
      bit [7:0] exp_byte = tx_expected_q.pop_front();
      
      // Mask expected data according to configured data size
      bit [7:0] masked_exp_byte;
      bit [31:0] cfg_val = reg_model.cfg.get_mirrored_value();
      case (cfg_val[4:3]) // data_size is bits [4:3]
        2'b00:   masked_exp_byte = exp_byte & 8'h1F; // 5 bits
        2'b01:   masked_exp_byte = exp_byte & 8'h3F; // 6 bits
        2'b10:   masked_exp_byte = exp_byte & 8'h7F; // 7 bits
        2'b11:   masked_exp_byte = exp_byte & 8'hFF; // 8 bits
        default: masked_exp_byte = exp_byte & 8'hFF;
      endcase

      if (trans.data !== masked_exp_byte) begin
        `uvm_error("SCB_TX_MISMATCH", $sformatf("TX Mismatch! Captured serial data %h, Expected APB data %h (masked %h)", trans.data, exp_byte, masked_exp_byte))
      end else begin
        `uvm_info("SCB_TX_MATCH", $sformatf("TX Match! Captured serial data %h matched expected %h", trans.data, masked_exp_byte), UVM_MEDIUM)
      end
    end
  endfunction

  // UART RX Driver write implementation (captures serial frames driven into the DUT's rx_serial line)
  function void write_uart_rx(uart_seq_item trans);
    bit [31:0] cfg_val = reg_model.cfg.get_mirrored_value();
    if (cfg_val[9] == 1'b1) begin // rx_enable is bit 9
      // If the scoreboard queue already contains a byte, it means the CPU hasn't read it yet.
      // Driving a new byte will cause an overrun in hardware, overwriting the buffered byte.
      if (rx_expected_q.size() >= 1) begin
        bit [7:0] discarded = rx_expected_q.pop_front();
        `uvm_info("SCB_RX_OVERRUN", $sformatf("Scoreboard predicted Data Overrun! Overwriting discarded byte %h with new byte %h.", discarded, trans.data), UVM_MEDIUM)
      end

      `uvm_info("SCB_RX", $sformatf("Expected RX Byte driven on serial line: %h", trans.data), UVM_MEDIUM)
      rx_expected_q.push_back(trans.data);
    end
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (tx_expected_q.size() != 0) begin
      `uvm_error("SCB_CHECK_PHASE", $sformatf("Simulation ended, but tx_expected_q is not empty! Remaining: %0d", tx_expected_q.size()))
    end
    if (rx_expected_q.size() != 0) begin
      `uvm_warning("SCB_CHECK_PHASE", $sformatf("Simulation ended, but rx_expected_q is not empty! Remaining: %0d", rx_expected_q.size()))
    end

    // Verify that the number of tx_done interrupts matches the number of enabled TX writes
    `uvm_info("SCB_CHECK_PHASE", $sformatf("Comparing interrupt counters: tx_write_count=%0d, tx_done_intr_count=%0d", tx_write_count, tx_done_intr_count), UVM_MEDIUM)
    if (tx_write_count != tx_done_intr_count) begin
      `uvm_error("SCB_INTR_MISMATCH", $sformatf("Interrupt verification failed! Number of enabled TX writes (%0d) does not match irq_tx_done counts (%0d)", tx_write_count, tx_done_intr_count))
    end else begin
      `uvm_info("SCB_INTR_VERIFIED", $sformatf("Interrupt verification successful! Enabled TX writes and irq_tx_done counts match: %0d", tx_done_intr_count), UVM_MEDIUM)
    end
  endfunction

endclass
