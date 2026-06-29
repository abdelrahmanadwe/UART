`timescale 1ns/1ps

import uart_defs::*;

module tb_uart_top;

  // Clock & Reset
  logic        clk;
  logic        rst_n;

  // APB Bus Interface Wires
  logic [4:0]  PADDR;
  logic        PSEL;
  logic        PENABLE;
  logic        PWRITE;
  logic [31:0] PWDATA;
  logic        PREADY;
  logic [31:0] PRDATA;
  logic        PSLVERR;

  // Serial loopback connection
  logic        serial_line;

  // Interrupt Outputs
  logic        irq_tx_ready;
  logic        irq_tx_done;
  logic        irq_rx_done;
  logic        irq_rx_parity;
  logic        irq_rx_framing;
  logic        irq_rx_overrun;
  logic        irq;

  // Testbench tracking helper
  logic        rx_done_irq_seen;
  logic        rx_overrun_irq_seen;

  // Clock generation: 50MHz (20ns period)
  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end

  // Reset generation
  initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
  end

  // Instantiate UART System Wrapper (loopback tx_serial -> rx_serial)
  UART u_dut (
    .PCLK           (clk),
    .PRESETn        (rst_n),
    .PADDR          (PADDR),
    .PSEL           (PSEL),
    .PENABLE        (PENABLE),
    .PWRITE         (PWRITE),
    .PWDATA         (PWDATA),
    .PREADY         (PREADY),
    .PRDATA         (PRDATA),
    .PSLVERR        (PSLVERR),
    .tx_serial      (serial_line),
    .rx_serial      (serial_line), // Loopback connection
    .irq_tx_ready   (irq_tx_ready),
    .irq_tx_done    (irq_tx_done),
    .irq_rx_done    (irq_rx_done),
    .irq_rx_parity  (irq_rx_parity),
    .irq_rx_framing (irq_rx_framing),
    .irq_rx_overrun (irq_rx_overrun),
    .irq            (irq)
  );

  // Address Decodes (matched with RTL - 5-bit byte offset)
  localparam bit [4:0] ADDR_CFG       = 5'h00;
  localparam bit [4:0] ADDR_STATUS    = 5'h04;
  localparam bit [4:0] ADDR_INTR_RAW  = 5'h08;
  localparam bit [4:0] ADDR_INTR_EN   = 5'h0C;
  localparam bit [4:0] ADDR_INTR_MASK = 5'h10;
  localparam bit [4:0] ADDR_TX_DATA   = 5'h14;
  localparam bit [4:0] ADDR_RX_DATA   = 5'h18;
  localparam bit [4:0] ADDR_BAUD_DIV  = 5'h1C;

  // Queue to track expected loopback data
  logic [7:0] expected_queue[$];
  
  // Semaphore for APB bus arbitration
  semaphore bus_sem = new(1);

  // Helper logic to disable monitor reading to test overrun
  logic disable_monitor_reads = 1'b0;

  // Task to write a register over APB
  task automatic write_reg(input logic [4:0] addr, input logic [31:0] data);
    bus_sem.get(1);
    @(posedge clk);
    PADDR   <= addr;
    PWRITE  <= 1'b1;
    PSEL    <= 1'b1;
    PWDATA  <= data;
    PENABLE <= 1'b0;
    @(posedge clk);
    PENABLE <= 1'b1;
    @(posedge clk);
    PSEL    <= 1'b0;
    PENABLE <= 1'b0;
    bus_sem.put(1);
  endtask

  // Task to read a register over APB
  task automatic read_reg(input logic [4:0] addr, output logic [31:0] data);
    bus_sem.get(1);
    @(posedge clk);
    PADDR   <= addr;
    PWRITE  <= 1'b0;
    PSEL    <= 1'b1;
    PENABLE <= 1'b0;
    @(posedge clk);
    PENABLE <= 1'b1;
    @(posedge clk);
    #1; // Wait for read data to stabilize
    data    = PRDATA;
    PSEL    <= 1'b0;
    PENABLE <= 1'b0;
    bus_sem.put(1);
  endtask

  // Helper task to poll STATUS until tx_ready (bit 0) is 1
  task automatic wait_tx_ready;
    logic [31:0] status_val;
    status_val = 32'h0;
    while (status_val[0] == 1'b0) begin
      read_reg(ADDR_STATUS, status_val);
    end
  endtask

  // Task to send a single byte through Register File
  task automatic send_byte(input [7:0] data);
    wait_tx_ready();
    expected_queue.push_back(data);
    write_reg(ADDR_TX_DATA, {24'h0, data});
  endtask

  // Stimulus Process
  initial begin
    logic [31:0] temp_val;

    // Initialize APB bus signals
    PADDR   = 5'h0;
    PWDATA  = 32'h0;
    PSEL    = 1'b0;
    PENABLE = 1'b0;
    PWRITE  = 1'b0;

    // Wait for reset release
    @(posedge rst_n);
    repeat (10) @(posedge clk);

    $display("=== STARTING UART REGISTER-BASED LOOPBACK TESTBENCH ===");

    // ==========================================
    // Pre-test: Verify TX/RX Disables Gating (Default)
    // ==========================================
    $display("\n[PRE-TEST] Verifying TX/RX Disables (Defaults to disabled)");
    // Try writing to TX_DATA while tx_enable is 0. Since tx_enable_ctrl is 0,
    // the write should be blocked at register file level and ignored.
    write_reg(ADDR_TX_DATA, 32'hA5);
    repeat (500) @(posedge clk);
    if (serial_line !== 1'b1) $error("TX transmitted data when disabled!");
    $display("[PRE-TEST] TX disabling verified successfully.");

    // Now enable TX/RX by writing 32'h318 (10'b11_0001_1000) to ADDR_CFG and 163 to ADDR_BAUD_DIV
    $display("[PRE-TEST] Enabling TX and RX...");
    write_reg(ADDR_CFG, 32'h318);
    write_reg(ADDR_BAUD_DIV, 32'd163);
    repeat (10) @(posedge clk);

    // ==========================================
    // Test Case 1: 8-bit, No Parity, 1 Stop, 19.2K (Defaults)
    // ==========================================
    // Config Register: size=2'b11, parity=2'b00, stop=1'b0, tx/rx enabled => 10'h318 (set in pre-test)
    // Divisor Register: 163 (19.2K Baud)
    
    send_byte(8'hA5);
    
    // Wait for reception to finish (by checking the expected queue)
    while (expected_queue.size() > 0) begin
      repeat (100) @(posedge clk);
    end
    repeat (2000) @(posedge clk); // additional padding

    // ==========================================
    // Test Case 2: Config modification: 5-bit, Odd Parity, 2 Stop, 19.2K
    // ==========================================
    $display("\n[TEST CASE 2] Config change: 5-bit, Odd Parity, 2 Stop, 19.2K Baud");
    // Config bit layout:
    // [2:0] = 3'b011 (BAUD_19200)
    // [4:3] = 2'b00  (DATA_5_BITS)
    // [6:5] = 2'b11  (PARITY_ODD) - AVR table 64 standard
    // [7]   = 1'b1   (STOP_2_BITS)
    // [8]   = 1'b1   (tx_enable)
    // [9]   = 1'b1   (rx_enable)
    // CFG value (baud rate bits are 0/ignored): 10'b11_1_11_00_000 = 10'h3E0
    write_reg(ADDR_CFG, 32'h3E0);
    write_reg(ADDR_BAUD_DIV, 32'd163);
    repeat (10) @(posedge clk);

    send_byte(8'h1F);
    while (expected_queue.size() > 0) begin
      repeat (100) @(posedge clk);
    end
    repeat (2000) @(posedge clk);

    // ==========================================
    // Test Case 3: Interrupt & Event Verification (Raw, IE, MIS, W1C)
    // ==========================================
    $display("\n[TEST CASE 3] Interrupt Enable, Masking, and W1C Verification");
    
    // Config: 8-bit, No Parity, 1 Stop, enabled, divisor = 163
    write_reg(ADDR_CFG, 32'h318);
    write_reg(ADDR_BAUD_DIV, 32'd163);
    
    // Clear any leftover raw interrupt flags from previous test cases (W1C)
    write_reg(ADDR_INTR_RAW, 32'h3F);
    repeat (5) @(posedge clk);
    
    // 1. Ensure interrupts are disabled initially, and RAW/MASK are matching expectations
    // Note that INTR_RAW[4] (tx_ready_raw) is level-sensitive and should be 1 because the buffer is empty.
    read_reg(ADDR_INTR_RAW, temp_val);
    $display("[TEST] Initial INTR_RAW: %h (Expected: bit 4 is 1, bits 3:0 & 5 are 0)", temp_val);
    if (temp_val[0] !== 1'b0 || temp_val[3] !== 1'b0 || temp_val[4] !== 1'b1 || temp_val[5] !== 1'b0) $error("INTR_RAW did not match expectations!");

    read_reg(ADDR_INTR_MASK, temp_val);
    $display("[TEST] Initial INTR_MASK: %h (Expected: 0)", temp_val);
    if (temp_val[0] !== 1'b0 || temp_val[3] !== 1'b0 || temp_val[4] !== 1'b0 || temp_val[5] !== 1'b0) $error("INTR_MASK did not match expectations!");
    if (irq !== 1'b0) $error("Global irq not 0!");

    // 2. Enable TX Done (bit 0) and RX Done (bit 3) interrupts (IER = 6'b001001 = 9)
    write_reg(ADDR_INTR_EN, 32'h9);
    
    // 3. Send a byte to trigger interrupts
    $display("[TEST] Sending byte to trigger TX/RX Done interrupts...");
    send_byte(8'h77);
    
    // Wait for data reception
    while (expected_queue.size() > 0) begin
      repeat (100) @(posedge clk);
    end

    // Wait until global interrupt goes high
    while (irq === 1'b0) begin
      @(posedge clk);
    end
    $display("[TEST] Global irq went high!");

    // 4. Verify Raw & Masked interrupt status registers
    // Since RX Done is auto-cleared on read (which the monitor did), raw_reg[3] should be 0, but rx_done_irq_seen should be 1.
    read_reg(ADDR_INTR_RAW, temp_val);
    $display("[TEST] Active INTR_RAW: %h (Expected: 1 for TX Done, RX Done auto-cleared on read)", temp_val);
    if (temp_val[0] !== 1'b1) $error("INTR_RAW[0] did not latch TX Done event!");
    if (rx_done_irq_seen !== 1'b1) $error("RX Done interrupt was not triggered during reception!");

    read_reg(ADDR_INTR_MASK, temp_val);
    $display("[TEST] Active INTR_MASK: %h (Expected: 1 for TX Done Masked)", temp_val);
    if (temp_val[0] !== 1'b1) $error("INTR_MASK[0] did not mask TX Done event!");

    if (irq_tx_done !== 1'b1) $error("irq_tx_done output pin is not high!");

    // 5. Clear remaining raw interrupts (TX Done) by writing 1 to it (W1C)
    $display("[TEST] Clearing TX Done interrupt via W1C...");
    write_reg(ADDR_INTR_RAW, 32'h1);
    repeat (5) @(posedge clk);

    // 6. Verify interrupts went low
    read_reg(ADDR_INTR_RAW, temp_val);
    $display("[TEST] Post-clear INTR_RAW: %h (Expected: bit 0 is 0)", temp_val);
    if (temp_val[0] !== 1'b0) $error("INTR_RAW[0] failed to clear on W1C!");

    if (irq !== 1'b0) $error("Global irq failed to go low after clear!");
    $display("[TEST] Interrupt clear verified successfully.");

    // 7. Verify Level-Sensitive TX Ready (UDRE) Interrupt
    $display("[TEST] Verifying level-sensitive TX Ready (UDRE) Interrupt...");
    if (irq_tx_ready !== 1'b0 || irq !== 1'b0) $error("TX Ready interrupt active before enable!");
    
    // Enable TX Ready interrupt (bit 4 of IER)
    write_reg(ADDR_INTR_EN, 32'h10);
    repeat (5) @(posedge clk);
    
    // Since transmitter is idle, irq_tx_ready and global irq must immediately go high!
    if (irq_tx_ready !== 1'b1 || irq !== 1'b1) $error("TX Ready level interrupt did not trigger immediately upon enable!");
    $display("[TEST] TX Ready triggered immediately as expected.");

    // Write a byte to TX_DATA. This should immediately pull tx_ready_hw low, deasserting the level interrupt!
    $display("[TEST] Writing byte. Interrupt should go low during active transmit...");
    expected_queue.push_back(8'h88);
    write_reg(ADDR_TX_DATA, 32'h88);
    
    // Wait a couple of cycles for state changes, but do not wait for transmission to complete
    repeat (20) @(posedge clk);
    if (irq_tx_ready !== 1'b0) $error("TX Ready level interrupt did not drop when TX buffer became full!");
    $display("[TEST] TX Ready interrupt dropped during transmission.");

    // Wait for the transmission to finish
    while (expected_queue.size() > 0) begin
      repeat (100) @(posedge clk);
    end
    repeat (50) @(posedge clk);

    // TX Ready should go high again after transmission finishes
    if (irq_tx_ready !== 1'b1) $error("TX Ready level interrupt did not go back high after transmission finished!");
    $display("[TEST] TX Ready went back high after transmission finished.");

    // Disable TX Ready interrupt
    write_reg(ADDR_INTR_EN, 32'h0);
    repeat (5) @(posedge clk);
    if (irq_tx_ready !== 1'b0 || irq !== 1'b0) $error("TX Ready level interrupt did not drop after disabling!");
    $display("[TEST] TX Ready interrupt verification completed successfully.");

    // ==========================================
    // Test Case 4: Back-to-Back transmissions
    // ==========================================
    $display("\n[TEST CASE 4] Back-to-Back Register Loopback: 8'h33 then 8'hCC");
    write_reg(ADDR_CFG, 32'h318);
    write_reg(ADDR_BAUD_DIV, 32'd163);
    repeat (10) @(posedge clk);

    // Send first byte
    send_byte(8'h33);
    
    // Send second byte (it will wait for tx_ready inside send_byte, making it back-to-back)
    send_byte(8'hCC);

    // Wait until both bytes are received
    while (expected_queue.size() > 0) begin
      repeat (100) @(posedge clk);
    end
    repeat (2000) @(posedge clk);

    // ==========================================
    // Test Case 5: 115200 Baud Verification
    // ==========================================
    $display("\n[TEST CASE 5] High Speed: 8-bit, No Parity, 1 Stop, 115.2K Baud");
    // Config:
    // [2:0] = 3'b100 (BAUD_115200)
    // [4:3] = 2'b11  (DATA_8_BITS)
    // [6:5] = 2'b00  (PARITY_NONE)
    // [7]   = 1'b0   (STOP_1_BIT)
    // [8]   = 1'b1   (tx_enable)
    // [9]   = 1'b1   (rx_enable)
    // CFG value: 10'b11_0001_1000 = 10'h318
    write_reg(ADDR_CFG, 32'h318);
    write_reg(ADDR_BAUD_DIV, 32'd27); // 50M / (115200 * 16) = 27.12 -> 27
    repeat (10) @(posedge clk);

    send_byte(8'hE9);
    while (expected_queue.size() > 0) begin
      repeat (100) @(posedge clk);
    end
    repeat (2000) @(posedge clk);

    // ==========================================
    // Test Case 6: Data OverRun (DOR) Verification
    // ==========================================
    $display("\n[TEST CASE 6] Data OverRun (DOR) Verification");
    
    // Clear raw interrupts
    write_reg(ADDR_INTR_RAW, 32'h3F);
    repeat (5) @(posedge clk);
    
    // Enable rx_done (bit 3) and overrun_error (bit 5) interrupts (IER = 6'b101000 = 32'h28)
    write_reg(ADDR_INTR_EN, 32'h28);
    // Write 19200 divisor to ensure clean state
    write_reg(ADDR_BAUD_DIV, 32'd163);
    repeat (5) @(posedge clk);

    // Disable automatic reads in monitor thread
    disable_monitor_reads = 1'b1;
    $display("[TEST] Disabled monitor reads to force Overrun...");

    // Send first byte (8'hAA)
    $display("[TEST] Sending first byte (8'hAA)...");
    send_byte(8'hAA);
    
    // Wait until tx_done raw interrupt goes high to confirm first transmission finished
    read_reg(ADDR_INTR_RAW, temp_val);
    while (temp_val[0] == 1'b0) begin
      repeat (100) @(posedge clk);
      read_reg(ADDR_INTR_RAW, temp_val);
    end
    // Clear tx_done Raw interrupt flag via W1C
    write_reg(ADDR_INTR_RAW, 32'h1);
    
    // Verify STATUS shows rx_valid is 1, and dor is 0
    read_reg(ADDR_STATUS, temp_val);
    $display("[TEST] Post-first-byte STATUS: %h (Expected: rx_valid=1, dor=0)", temp_val);
    if (temp_val[1] !== 1'b1 || temp_val[2] !== 1'b0) $error("STATUS after first byte incorrect!");

    // Send second byte (8'h55)
    $display("[TEST] Sending second byte (8'h55) to trigger overrun...");
    send_byte(8'h55);
    
    // Wait until tx_done raw interrupt goes high to confirm second transmission finished
    read_reg(ADDR_INTR_RAW, temp_val);
    while (temp_val[0] == 1'b0) begin
      repeat (100) @(posedge clk);
      read_reg(ADDR_INTR_RAW, temp_val);
    end
    // Clear tx_done Raw interrupt flag via W1C
    write_reg(ADDR_INTR_RAW, 32'h1);

    // Verify STATUS shows rx_valid is 1, and dor is 1
    read_reg(ADDR_STATUS, temp_val);
    $display("[TEST] Post-second-byte STATUS: %h (Expected: rx_valid=1, dor=1)", temp_val);
    if (temp_val[1] !== 1'b1 || temp_val[2] !== 1'b1) $error("STATUS after overrun incorrect!");

    // Verify overrun raw interrupt is active, and irq_rx_overrun output is high
    read_reg(ADDR_INTR_RAW, temp_val);
    $display("[TEST] Overrun INTR_RAW: %h (Expected: bit 5 is 1)", temp_val);
    if (temp_val[5] !== 1'b1) $error("INTR_RAW[5] not set on overrun!");
    if (irq_rx_overrun !== 1'b1) $error("irq_rx_overrun output pin not high!");
    if (irq !== 1'b1) $error("Global irq not high on overrun!");

    // Pop the first byte (8'hAA) from the expected queue because it was overwritten and lost
    if (expected_queue.size() > 0) void'(expected_queue.pop_front());
    
    // Re-enable monitor reads so it reads the overrun byte (8'h55)
    disable_monitor_reads = 1'b0;
    $display("[TEST] Re-enabled monitor reads.");
    
    // Wait for the monitor to complete reading
    repeat (200) @(posedge clk);

    // Verify STATUS shows rx_valid is 0, and dor is 0
    read_reg(ADDR_STATUS, temp_val);
    $display("[TEST] Post-read STATUS: %h (Expected: rx_valid=0, dor=0)", temp_val);
    if (temp_val[1] !== 1'b0 || temp_val[2] !== 1'b0) $error("STATUS failed to clear on RX_DATA read!");

    // Verify overrun and rx_done raw interrupts have been cleared
    read_reg(ADDR_INTR_RAW, temp_val);
    $display("[TEST] Post-read INTR_RAW: %h (Expected: bits 5 & 3 are 0)", temp_val);
    if (temp_val[5] !== 1'b0 || temp_val[3] !== 1'b0) $error("INTR_RAW failed to clear on RX_DATA read!");

    // Disable interrupts
    write_reg(ADDR_INTR_EN, 32'h0);
    repeat (100) @(posedge clk);

    $display("\n=== ALL REGISTER-BASED LOOPBACK TESTS PASSED SUCCESSFULLY ===");
    $finish;
  end

  // Watchdog timer (20ms)
  initial begin
    #20000000;
    $display("[WATCHDOG] Simulation timeout reached! Loopback hung.");
    $finish;
  end

  // Monitor Process for APB register-based loopback
  initial begin
    logic [31:0] status;
    logic [31:0] rx_val;
    forever begin
      read_reg(ADDR_STATUS, status);
      if (status[1] && !disable_monitor_reads) begin
        // Read received byte
        read_reg(ADDR_RX_DATA, rx_val);
        $display("[MONITOR @ %0t] Read received byte: %h (Expected: %h, raw: %h)", 
                 $time, rx_val[7:0], expected_queue.size() > 0 ? expected_queue[0] : 8'h00, rx_val[7:0]);
        if (expected_queue.size() > 0) begin
          logic [7:0] exp;
          exp = expected_queue.pop_front();
          if (rx_val[7:0] !== exp) begin
            $error("[MONITOR ERROR @ %0t] Data mismatch! Got %h, Expected %h", $time, rx_val[7:0], exp);
          end else begin
            $display("[MONITOR @ %0t] Data match verified successfully.", $time);
          end
        end else begin
          $error("[MONITOR ERROR @ %0t] Unexpected data received: %h", $time, rx_val[7:0]);
        end
      end
      repeat (10) @(posedge clk);
    end
  end

  // Latch RX Done and Overrun interrupt events in testbench since they are auto-cleared on read
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_done_irq_seen    <= 1'b0;
      rx_overrun_irq_seen <= 1'b0;
    end else begin
      if (irq_rx_done) begin
        rx_done_irq_seen <= 1'b1;
      end else if (PSEL && PENABLE && PWRITE && PADDR == ADDR_INTR_RAW && PWDATA[3]) begin
        rx_done_irq_seen <= 1'b0;
      end

      if (irq_rx_overrun) begin
        rx_overrun_irq_seen <= 1'b1;
      end else if (PSEL && PENABLE && PWRITE && PADDR == ADDR_INTR_RAW && PWDATA[5]) begin
        rx_overrun_irq_seen <= 1'b0;
      end
    end
  end

endmodule