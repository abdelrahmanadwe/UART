import uvm_pkg::*;
`include "uvm_macros.svh"

// -----------------------------------------------------------------------------
// Base Virtual Sequence
// -----------------------------------------------------------------------------
class uart_vseq_base extends uvm_sequence;
  `uvm_object_utils(uart_vseq_base)

  // Sub-sequencer handles
  apb_sequencer   apb_seqr;
  uart_sequencer  uart_seqr;

  // RAL model handle
  uart_reg_block  reg_model;

  function new(string name = "uart_vseq_base");
    super.new(name);
  endfunction

  // Helper task to read raw status register value
  task read_status_reg(output bit [31:0] val);
    uvm_status_e status;
    reg_model.status.read(status, val, .parent(this));
  endtask

  // Helper task to write config register
  task write_cfg_reg(input bit [31:0] val);
    uvm_status_e status;
    reg_model.cfg.write(status, val, .parent(this));
  endtask
endclass

// -----------------------------------------------------------------------------
// Register Access Virtual Sequence (tests register read/write and reset values)
// -----------------------------------------------------------------------------
class uart_reg_access_vseq extends uart_vseq_base;
  `uvm_object_utils(uart_reg_access_vseq)

  function new(string name = "uart_reg_access_vseq");
    super.new(name);
  endfunction

  task body();
    uvm_status_e status;
    bit [31:0] read_val;

    `uvm_info("VSEQ_REG", "Starting Register Access Verification...", UVM_MEDIUM)

    reg_model.cfg.read(status, read_val, .parent(this));
    if (read_val !== 32'h18) begin // Default config on reset: disables active, size=3 => 32'h18
      `uvm_error("VSEQ_REG_ERR", $sformatf("CFG register reset value mismatch! Got %h, Expected 18", read_val))
    end

    reg_model.baud_div.read(status, read_val, .parent(this));
    if (read_val !== 32'd163) begin // Default divisor is 163 (19.2K)
      `uvm_error("VSEQ_REG_ERR", $sformatf("BAUD_DIV register reset value mismatch! Got %d, Expected 163", read_val))
    end

    reg_model.status.read(status, read_val, .parent(this));
    if (read_val !== 32'h1) begin // Default status: tx_ready is 1, others 0
      `uvm_error("VSEQ_REG_ERR", $sformatf("STATUS register reset value mismatch! Got %h, Expected 1", read_val))
    end

    reg_model.ier.read(status, read_val, .parent(this));
    if (read_val !== 32'h0) begin
      `uvm_error("VSEQ_REG_ERR", $sformatf("IER register reset value mismatch! Got %h, Expected 0", read_val))
    end

    // 2. Perform Writes & Readbacks
    // Configure: enable TX/RX, 8-bit => CFG value: 10'h318
    reg_model.cfg.write(status, 32'h318, .parent(this));
    reg_model.baud_div.write(status, 32'd27, .parent(this)); // 115.2K baud

    reg_model.cfg.read(status, read_val, .parent(this));
    if (read_val !== 32'h318) begin
      `uvm_error("VSEQ_REG_ERR", $sformatf("CFG readback mismatch! Got %h, Expected 318", read_val))
    end

    reg_model.baud_div.read(status, read_val, .parent(this));
    if (read_val !== 32'd27) begin
      `uvm_error("VSEQ_REG_ERR", $sformatf("BAUD_DIV readback mismatch! Got %d, Expected 27", read_val))
    end

    // Configure IER: Enable TX Done & Overrun interrupts => IER value: 32'h29
    reg_model.ier.write(status, 32'h29, .parent(this));
    reg_model.ier.read(status, read_val, .parent(this));
    if (read_val !== 32'h29) begin
      `uvm_error("VSEQ_REG_ERR", $sformatf("IER readback mismatch! Got %h, Expected 29", read_val))
    end

    // Restore to default config
    reg_model.cfg.write(status, 32'h018, .parent(this));
    reg_model.baud_div.write(status, 32'd163, .parent(this));
    reg_model.ier.write(status, 32'h0, .parent(this));

    `uvm_info("VSEQ_REG", "Register Access Verification Complete.", UVM_MEDIUM)
  endtask
endclass

// -----------------------------------------------------------------------------
// Loopback Virtual Sequence (sends serial data and checks TX/RX data paths)
// -----------------------------------------------------------------------------
class uart_loopback_vseq extends uart_vseq_base;
  `uvm_object_utils(uart_loopback_vseq)

  function new(string name = "uart_loopback_vseq");
    super.new(name);
  endfunction

  task body();
    uvm_status_e status;
    bit [31:0] read_val;
    uart_seq_item uart_item;

    `uvm_info("VSEQ_LOOPBACK", "Starting Loopback Data Path Verification...", UVM_MEDIUM)

    // 1. Enable TX and RX in CFG (8-bit, No Parity, 1 Stop => 10'h318, Divisor = 163)
    reg_model.cfg.write(status, 32'h318, .parent(this));
    reg_model.baud_div.write(status, 32'd163, .parent(this));

    // 2. Test APB-to-Serial Transmitter (TX) Path
    // Write 8'hA5 to TX_DATA over APB
    reg_model.tx_data.write(status, 32'hA5, .parent(this));
    
    // Wait for transmit to complete (poll STATUS.tx_ready until it goes back to 1)
    read_val = 32'h0;
    while (read_val[0] == 1'b0) begin
      reg_model.status.read(status, read_val, .parent(this));
      #100ns;
    end
    #200000ns; // Wait for receiver loopback to finish processing

    // 3. Test Serial-to-APB Receiver (RX) Path
    // Drive serial frame (8'h5A) onto rx_serial using UART Serial Agent
    uart_item = uart_seq_item::type_id::create("uart_item");
    uart_item.data        = 8'h5A;
    uart_item.data_size   = DATA_8_BITS;
    uart_item.parity_ctrl = PARITY_NONE;
    uart_item.stop_bits   = STOP_1_BIT;
    uart_item.baud_div    = 16'd163;
    uart_item.error_type  = ERR_NONE;
    
    // Start sequence item on UART agent sequencer
    start_item(uart_item, .sequencer(uart_seqr));
    finish_item(uart_item);

    // Wait for STATUS.rx_valid to become 1
    read_val = 32'h0;
    while (read_val[1] == 1'b0) begin
      reg_model.status.read(status, read_val, .parent(this));
      #100ns;
    end

    // Read received data via APB (will trigger scoreboard check)
    reg_model.rx_data.read(status, read_val, .parent(this));

    `uvm_info("VSEQ_LOOPBACK", "Loopback Data Path Verification Complete.", UVM_MEDIUM)
  endtask
endclass

// -----------------------------------------------------------------------------
// Data OverRun (DOR) Virtual Sequence
// -----------------------------------------------------------------------------
class uart_overrun_vseq extends uart_vseq_base;
  `uvm_object_utils(uart_overrun_vseq)

  function new(string name = "uart_overrun_vseq");
    super.new(name);
  endfunction

  task body();
    uvm_status_e status;
    bit [31:0] read_val;
    uart_seq_item uart_item1, uart_item2;

    `uvm_info("VSEQ_OVERRUN", "Starting Data OverRun (DOR) Verification...", UVM_MEDIUM)

    // 1. Enable TX and RX (10'h318, Divisor = 163)
    reg_model.cfg.write(status, 32'h318, .parent(this));
    reg_model.baud_div.write(status, 32'd163, .parent(this));
    
    // Clear raw interrupts (W1C)
    reg_model.ris.write(status, 32'h3F, .parent(this));

    // 2. Drive first serial byte (8'hAA) - do NOT read RX_DATA
    uart_item1 = uart_seq_item::type_id::create("uart_item1");
    uart_item1.data        = 8'hAA;
    uart_item1.data_size   = DATA_8_BITS;
    uart_item1.parity_ctrl = PARITY_NONE;
    uart_item1.stop_bits   = STOP_1_BIT;
    uart_item1.baud_div    = 16'd163;
    uart_item1.error_type  = ERR_NONE;

    start_item(uart_item1, .sequencer(uart_seqr));
    finish_item(uart_item1);

    // Wait for first byte reception to finish (rx_valid = 1)
    read_val = 32'h0;
    while (read_val[1] == 1'b0) begin
      reg_model.status.read(status, read_val, .parent(this));
      #100ns;
    end
    $display("[VSEQ] First byte received. STATUS = %h (Expected rx_valid=1, dor=0)", read_val);

    // 3. Drive second serial byte (8'h55) immediately to trigger Overrun
    uart_item2 = uart_seq_item::type_id::create("uart_item2");
    uart_item2.data        = 8'h55;
    uart_item2.data_size   = DATA_8_BITS;
    uart_item2.parity_ctrl = PARITY_NONE;
    uart_item2.stop_bits   = STOP_1_BIT;
    uart_item2.baud_div    = 16'd163;
    uart_item2.error_type  = ERR_NONE;

    start_item(uart_item2, .sequencer(uart_seqr));
    finish_item(uart_item2);

    // Wait for second byte reception to finish (tx_done of transmitter or just wait a frame time)
    #600000ns; 

    // 4. Read STATUS and verify `dor == 1`
    reg_model.status.read(status, read_val, .parent(this));
    $display("[VSEQ] Post-second-byte STATUS = %h (Expected rx_valid=1, dor=1)", read_val);
    if (read_val[2] !== 1'b1) begin
      `uvm_error("VSEQ_OVERRUN_ERR", "Data Overrun flag (STATUS[2]) not set on double reception!")
    end

    // Verify overrun raw interrupt is active
    reg_model.ris.read(status, read_val, .parent(this));
    if (read_val[5] !== 1'b1) begin
      `uvm_error("VSEQ_OVERRUN_ERR", "Overrun Raw Interrupt (RIS[5]) not set on double reception!")
    end

    // 5. Read RX_DATA - this must automatically clear STATUS.rx_valid, STATUS.dor, and RIS overrun interrupt!
    reg_model.rx_data.read(status, read_val, .parent(this));
    $display("[VSEQ] Read RX_DATA value: %h (Expected: 55, since AA was overwritten)", read_val);
    if (read_val[7:0] !== 8'h55) begin
      `uvm_error("VSEQ_OVERRUN_ERR", $sformatf("RX_DATA mismatch! Got %h, Expected 55 (overwritten value)", read_val[7:0]))
    end

    // Verify STATUS cleared
    reg_model.status.read(status, read_val, .parent(this));
    $display("[VSEQ] Post-read STATUS = %h (Expected rx_valid=0, dor=0)", read_val);
    if (read_val[1] !== 1'b0 || read_val[2] !== 1'b0) begin
      `uvm_error("VSEQ_OVERRUN_ERR", "STATUS.rx_valid or STATUS.dor failed to clear on RX_DATA read!")
    end

    // Verify RIS cleared
    reg_model.ris.read(status, read_val, .parent(this));
    if (read_val[5] !== 1'b0 || read_val[3] !== 1'b0) begin
      `uvm_error("VSEQ_OVERRUN_ERR", "RIS.overrun_error or RIS.rx_done failed to clear on RX_DATA read!")
    end

    `uvm_info("VSEQ_OVERRUN", "Data OverRun (DOR) Verification Complete.", UVM_MEDIUM)
  endtask
endclass
