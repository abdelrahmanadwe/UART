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
    uart_send_frame_seq uart_seq;

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
    uart_seq = uart_send_frame_seq::type_id::create("uart_seq");
    uart_seq.data        = 8'h5A;
    uart_seq.data_size   = DATA_8_BITS;
    uart_seq.parity_ctrl = PARITY_NONE;
    uart_seq.stop_bits   = STOP_1_BIT;
    uart_seq.baud_div    = 16'd163;
    uart_seq.error_type  = ERR_NONE;
    
    // Start standard sequence on UART agent sequencer
    uart_seq.start(uart_seqr);

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
    uart_send_frame_seq uart_seq1, uart_seq2;

    `uvm_info("VSEQ_OVERRUN", "Starting Data OverRun (DOR) Verification...", UVM_MEDIUM)

    // 1. Enable TX and RX (10'h318, Divisor = 163)
    reg_model.cfg.write(status, 32'h318, .parent(this));
    reg_model.baud_div.write(status, 32'd163, .parent(this));
    
    // Clear raw interrupts (W1C)
    reg_model.ris.write(status, 32'h3F, .parent(this));

    // 2. Drive first serial byte (8'hAA) - do NOT read RX_DATA
    uart_seq1 = uart_send_frame_seq::type_id::create("uart_seq1");
    uart_seq1.data        = 8'hAA;
    uart_seq1.data_size   = DATA_8_BITS;
    uart_seq1.parity_ctrl = PARITY_NONE;
    uart_seq1.stop_bits   = STOP_1_BIT;
    uart_seq1.baud_div    = 16'd163;
    uart_seq1.error_type  = ERR_NONE;

    uart_seq1.start(uart_seqr);

    // Wait for first byte reception to finish (rx_valid = 1)
    read_val = 32'h0;
    while (read_val[1] == 1'b0) begin
      reg_model.status.read(status, read_val, .parent(this));
      #100ns;
    end
    $display("[VSEQ] First byte received. STATUS = %h (Expected rx_valid=1, dor=0)", read_val);

    // 3. Drive second serial byte (8'h55) immediately to trigger Overrun
    uart_seq2 = uart_send_frame_seq::type_id::create("uart_seq2");
    uart_seq2.data        = 8'h55;
    uart_seq2.data_size   = DATA_8_BITS;
    uart_seq2.parity_ctrl = PARITY_NONE;
    uart_seq2.stop_bits   = STOP_1_BIT;
    uart_seq2.baud_div    = 16'd163;
    uart_seq2.error_type  = ERR_NONE;

    uart_seq2.start(uart_seqr);

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

// -----------------------------------------------------------------------------
// Legal Randomized Virtual Sequence
// -----------------------------------------------------------------------------
class uart_rand_vseq extends uart_vseq_base;
  `uvm_object_utils(uart_rand_vseq)

  function new(string name = "uart_rand_vseq");
    super.new(name);
  endfunction

  task body();
    uvm_status_e status;
    bit [31:0] read_val;
    bit [7:0] rand_data;
    uart_send_frame_seq uart_seq;

    `uvm_info("VSEQ_RAND", "Starting Legal Randomized Verification...", UVM_MEDIUM)

    repeat (90) begin
      // 1. Randomize registers with strictly legal options
      // Data size: random (5 to 8 bits)
      // Parity: random (0=none, 2=even, 3=odd)
      // Stop bits: random (0=1 stop bit, 1=2 stop bits)
      // Enable TX and RX (both must be 1)
      if (!reg_model.cfg.randomize() with {
        tx_enable.value == 1'b1;
        rx_enable.value == 1'b1;
        parity.value    != 2'b01; // Exclude reserved parity from legal rand test!
      }) begin
        `uvm_error("VSEQ_RAND_ERR", "CFG register randomization failed")
      end

      // Baud Divisor: restrict to legal range [2 to 50] to cover small divisor coverage bins
      if (!reg_model.baud_div.randomize() with {
        divisor.value >= 16'd2;
        divisor.value <= 16'd50;
      }) begin
        `uvm_error("VSEQ_RAND_ERR", "BAUD_DIV register randomization failed")
      end

      // Write configurations to DUT
      reg_model.cfg.update(status, .parent(this));
      reg_model.baud_div.update(status, .parent(this));

      // Clear raw interrupts (W1C)
      reg_model.ris.write(status, 32'h3F, .parent(this));

      // 2. Perform a TX write and verify transmission
      rand_data = $urandom;
      `uvm_info("VSEQ_RAND", $sformatf("Writing random TX data: %h", rand_data), UVM_MEDIUM)
      reg_model.tx_data.write(status, {24'h0, rand_data}, .parent(this));

      // Poll tx_ready
      read_val = 32'h0;
      while (read_val[0] == 1'b0) begin
        reg_model.status.read(status, read_val, .parent(this));
        #100ns;
      end
      #150000ns; // Wait for transmission to propagate through monitor

      // 3. Perform a serial RX drive and verify reception
      rand_data = $urandom;
      `uvm_info("VSEQ_RAND", $sformatf("Driving random RX data: %h", rand_data), UVM_MEDIUM)

      uart_seq = uart_send_frame_seq::type_id::create("uart_seq");
      
      // Get the current mirrored configuration values
      begin
        bit [31:0] cfg_val = reg_model.cfg.get_mirrored_value();
        bit [31:0] div_val = reg_model.baud_div.get_mirrored_value();
        
        if (!uart_seq.randomize() with {
          data        == rand_data;
          data_size   == data_size_e'(cfg_val[4:3]);
          parity_ctrl == parity_ctrl_e'(cfg_val[6:5]);
          stop_bits   == stop_bits_e'(cfg_val[7]);
          baud_div    == div_val[15:0];
          error_type  == ERR_NONE;
        }) begin
          `uvm_error("VSEQ_RAND_ERR", "uart_send_frame_seq randomization failed")
        end
      end
      
      uart_seq.start(uart_seqr);

      // Poll rx_valid
      read_val = 32'h0;
      while (read_val[1] == 1'b0) begin
        reg_model.status.read(status, read_val, .parent(this));
        #100ns;
      end

      // Read RX_DATA (triggers scoreboard match checking)
      reg_model.rx_data.read(status, read_val, .parent(this));
    end

    `uvm_info("VSEQ_RAND", "Legal Randomized Verification Complete.", UVM_MEDIUM)
  endtask
endclass

// -----------------------------------------------------------------------------
// Illegal Randomized Virtual Sequence (Robustness Testing)
// -----------------------------------------------------------------------------
class uart_illegal_rand_vseq extends uart_vseq_base;
  `uvm_object_utils(uart_illegal_rand_vseq)

  function new(string name = "uart_illegal_rand_vseq");
    super.new(name);
  endfunction

  task body();
    uvm_status_e status;
    bit [31:0] read_val;
    bit [7:0] rand_data;
    uart_send_frame_seq uart_seq;

    `uvm_info("VSEQ_ILLEGAL", "Starting Illegal/Corner-Case Randomized Verification...", UVM_MEDIUM)

    // Clear raw interrupts (W1C)
    reg_model.ris.write(status, 32'h3F, .parent(this));

    // Case 1: Write illegal baud rate divisor = 0
    `uvm_info("VSEQ_ILLEGAL", "Case 1: Setting Baud Divisor = 0 (Illegal value)", UVM_MEDIUM)
    reg_model.baud_div.write(status, 32'h0, .parent(this));
    #1us;

    // Case 2: Write illegal parity bits = 2'b11
    `uvm_info("VSEQ_ILLEGAL", "Case 2: Setting parity = 2'b11 (Illegal value)", UVM_MEDIUM)
    reg_model.cfg.write(status, 32'h378, .parent(this)); // sets parity to 2'b11, stop to 1, tx/rx to 1, size to 3
    #1us;

    // Case 3: Read/Write to Unmapped Register addresses (corner cases)
    `uvm_info("VSEQ_ILLEGAL", "Case 3: Accessing Unmapped addresses (0x02, 0x06)", UVM_MEDIUM)
    begin
      apb_seq_item item = apb_seq_item::type_id::create("item");
      item.addr = 5'h02; // unmapped (not 4-byte aligned in a 5-bit address space)
      item.write = 1'b1;
      item.wdata = 32'hDEADBEEF;
      start_item(item, .sequencer(apb_seqr));
      finish_item(item);
      if (item.slverr !== 1'b1) begin
        `uvm_error("VSEQ_ILLEGAL_ERR", "PSLVERR not asserted on unmapped address write!")
      end

      item = apb_seq_item::type_id::create("item");
      item.addr = 5'h06; // unmapped
      item.write = 1'b0;
      start_item(item, .sequencer(apb_seqr));
      finish_item(item);
      if (item.slverr !== 1'b1) begin
        `uvm_error("VSEQ_ILLEGAL_ERR", "PSLVERR not asserted on unmapped address read!")
      end
    end

    // Restore to legal config for following serial transmission checks
    reg_model.cfg.write(status, 32'h318, .parent(this)); // 8-bit, no parity, 1 stop, tx/rx enabled
    reg_model.baud_div.write(status, 32'd163, .parent(this)); // 163 divisor
    #1us;

    // Case 4: Send serial frame with Parity Error
    `uvm_info("VSEQ_ILLEGAL", "Case 4: Injecting Parity Error on serial line", UVM_MEDIUM)
    reg_model.cfg.write(status, 32'h358, .parent(this)); // enable parity (even = 2'b10), tx/rx enabled
    reg_model.ris.write(status, 32'h3F, .parent(this)); // clear flags
    
    uart_seq = uart_send_frame_seq::type_id::create("uart_seq");
    if (!uart_seq.randomize() with {
      data        == 8'hA5;
      data_size   == DATA_8_BITS;
      parity_ctrl == PARITY_EVEN;
      stop_bits   == STOP_1_BIT;
      baud_div    == 16'd163;
      error_type  == ERR_PARITY; // Inject error!
    }) begin
      `uvm_error("VSEQ_ILLEGAL_ERR", "uart_send_frame_seq randomization failed")
    end
    uart_seq.start(uart_seqr);
    #300000ns;

    // Read STATUS and RIS to verify error flag is set
    reg_model.ris.read(status, read_val, .parent(this));
    $display("[VSEQ] RIS post parity error = %h (Expected parity_error=1 at bit 1)", read_val);
    if (read_val[1] !== 1'b1) begin
      `uvm_error("VSEQ_ILLEGAL_ERR", "Parity error flag (RIS[1]) not set on parity error reception!")
    end

    // Read RX_DATA to flush queue and clear hardware flags
    reg_model.rx_data.read(status, read_val, .parent(this));

    // Case 5: Send serial frame with Framing Error
    `uvm_info("VSEQ_ILLEGAL", "Case 5: Injecting Framing Error on serial line", UVM_MEDIUM)
    reg_model.ris.write(status, 32'h3F, .parent(this)); // clear flags
    reg_model.cfg.write(status, 32'h318, .parent(this)); // 8-bit, no parity, tx/rx enabled
    
    uart_seq = uart_send_frame_seq::type_id::create("uart_seq");
    if (!uart_seq.randomize() with {
      data        == 8'h5A;
      data_size   == DATA_8_BITS;
      parity_ctrl == PARITY_NONE;
      stop_bits   == STOP_1_BIT;
      baud_div    == 16'd163;
      error_type  == ERR_FRAMING; // Inject error!
    }) begin
      `uvm_error("VSEQ_ILLEGAL_ERR", "uart_send_frame_seq randomization failed")
    end
    uart_seq.start(uart_seqr);
    #300000ns;

    // Read RIS to verify framing error flag is set
    reg_model.ris.read(status, read_val, .parent(this));
    $display("[VSEQ] RIS post framing error = %h (Expected framing_error=1 at bit 2)", read_val);
    if (read_val[2] !== 1'b1) begin
      `uvm_error("VSEQ_ILLEGAL_ERR", "Framing error flag (RIS[2]) not set on framing error reception!")
    end

    // Read RX_DATA to flush queue and clear hardware flags
    reg_model.rx_data.read(status, read_val, .parent(this));

    // Case 6: Accessing Reserved/Unsupported Parity Mode (2'b01)
    // Run this under all data sizes and stop bit configurations to cover cross combinations of parity_rsvd!
    `uvm_info("VSEQ_ILLEGAL", "Case 6: Testing Reserved Parity Configuration (2'b01)", UVM_MEDIUM)
    reg_model.baud_div.write(status, 32'd10, .parent(this)); // Use small divisor to speed up simulation
    for (int sz = 0; sz < 4; sz++) begin
      for (int sb = 0; sb < 2; sb++) begin
        if (!reg_model.cfg.randomize() with {
          tx_enable.value == 1'b1;
          rx_enable.value == 1'b1;
          parity.value    == 2'b01; // Reserved/unused parity
          data_size.value == sz;
          stop_bits.value == sb;
        }) begin
          `uvm_error("VSEQ_ILLEGAL_ERR", "CFG register randomization failed for Case 6")
        end
        reg_model.cfg.update(status, .parent(this));

        // Send a byte to verify it transmits correctly (behaves like PARITY_NONE)
        rand_data = $urandom;
        reg_model.tx_data.write(status, {24'h0, rand_data}, .parent(this));

        // Poll tx_ready to ensure it completes
        read_val = 32'h0;
        while (read_val[0] == 1'b0) begin
          reg_model.status.read(status, read_val, .parent(this));
        end
        #100000ns; // Wait for transmission to propagate through monitor
      end
    end

    // Clear all flags and restore settings
    reg_model.ris.write(status, 32'h3F, .parent(this));
    reg_model.cfg.write(status, 32'h18, .parent(this));

    `uvm_info("VSEQ_ILLEGAL", "Illegal/Corner-Case Randomized Verification Complete.", UVM_MEDIUM)
  endtask
endclass
