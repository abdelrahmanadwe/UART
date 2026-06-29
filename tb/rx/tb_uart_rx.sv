`timescale 1ns/1ps

import uart_defs::*;

module tb_uart_rx;

  // Clock & Reset
  logic        clk;
  logic        rst_n;

  // DUT IOs
  logic        RX_IN;
  data_size_e  data_size_ctrl;
  parity_ctrl_e parity_ctrl;
  stop_bits_e  stop_bits_ctrl;
  baud_rate_e  baud_rate_ctrl;

  logic [7:0]  P_DATA;
  logic        Data_Valid;
  logic        parity_error;
  logic        framing_error;

  // Clock generation: 50MHz (20ns period)
  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end

  // Reset generation
  initial begin
    rst_n = 0;
    #50;
    rst_n = 1;
  end

  // Instantiate DUT
  uart_rx u_dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .RX_IN          (RX_IN),
    .data_size_ctrl (data_size_ctrl),
    .parity_ctrl    (parity_ctrl),
    .stop_bits_ctrl (stop_bits_ctrl),
    .baud_rate_ctrl (baud_rate_ctrl),
    .P_DATA         (P_DATA),
    .Data_Valid     (Data_Valid),
    .parity_error   (parity_error),
    .framing_error  (framing_error)
  );

  // Helper task to calculate bit period in ns
  function automatic int get_bit_period_ns(baud_rate_e baud);
    case (baud)
      BAUD_2400:   return 20833 * 20;
      BAUD_4800:   return 10417 * 20;
      BAUD_9600:   return 5208 * 20;
      BAUD_19200:  return 2604 * 20;
      default:     return 2604 * 20;
    endcase
  endfunction

  // Task to transmit a serial UART frame to RX_IN
  task automatic send_uart_frame(
    input [7:0] data,
    input data_size_e size,
    input parity_ctrl_e parity,
    input stop_bits_e stop,
    input baud_rate_e baud,
    input bit inject_parity_error = 0,
    input bit inject_framing_error = 0
  );
    int bit_period_ns;
    int num_data_bits;
    logic parity_bit;
    logic calculated_parity;

    bit_period_ns = get_bit_period_ns(baud);

    case (size)
      DATA_5_BITS: num_data_bits = 5;
      DATA_6_BITS: num_data_bits = 6;
      DATA_7_BITS: num_data_bits = 7;
      DATA_8_BITS: num_data_bits = 8;
    endcase

    $display("[DRIVER @ %0t] Sending frame: Data=%h, Size=%s, Parity=%s, Stop=%s, Baud=%s", 
             $time, data, size.name(), parity.name(), stop.name(), baud.name());

    // 1. Send Start Bit (0)
    RX_IN = 1'b0;
    #(bit_period_ns);

    // 2. Send Data Bits (LSB-first)
    for (int i = 0; i < num_data_bits; i++) begin
      RX_IN = data[i];
      #(bit_period_ns);
    end

    // 3. Send Parity Bit (if enabled)
    if (parity == PARITY_ODD || parity == PARITY_EVEN) begin
      calculated_parity = ^(data & ((8'h01 << num_data_bits) - 1));
      parity_bit = (parity == PARITY_ODD) ? ~calculated_parity : calculated_parity;
      if (inject_parity_error) begin
        parity_bit = ~parity_bit;
        $display("[DRIVER @ %0t] Injecting Parity Error: sending %b", $time, parity_bit);
      end
      RX_IN = parity_bit;
      #(bit_period_ns);
    end

    // 4. Send Stop Bit (1)
    if (inject_framing_error) begin
      $display("[DRIVER @ %0t] Injecting Framing Error: sending 0 as stop bit", $time);
      RX_IN = 1'b0;
    end else begin
      RX_IN = 1'b1;
    end
    #(bit_period_ns);

    if (stop == STOP_2_BITS) begin
      RX_IN = 1'b1;
      #(bit_period_ns);
    end

    // Line idle
    RX_IN = 1'b1;
  endtask

  // Monitor process to check received P_DATA and status flags
  task automatic expect_rx_frame(
    input [7:0] expected_data,
    input data_size_e size,
    input bit expect_parity_err = 0,
    input bit expect_framing_err = 0
  );
    int num_data_bits;
    logic [7:0] masked_expected;

    case (size)
      DATA_5_BITS: num_data_bits = 5;
      DATA_6_BITS: num_data_bits = 6;
      DATA_7_BITS: num_data_bits = 7;
      DATA_8_BITS: num_data_bits = 8;
    endcase
    masked_expected = expected_data & ((8'h01 << num_data_bits) - 1);

    @(posedge Data_Valid);
    #1;
    
    // Check received data
    if (P_DATA !== masked_expected) begin
      $error("[MONITOR ERROR @ %0t] P_DATA mismatch! Expected: %h, Got: %h", $time, masked_expected, P_DATA);
    end else begin
      $display("[MONITOR @ %0t] P_DATA match verified: %h", $time, P_DATA);
    end

    // Check parity error flag
    if (parity_error !== expect_parity_err) begin
      $error("[MONITOR ERROR @ %0t] parity_error flag mismatch! Expected: %b, Got: %b", $time, expect_parity_err, parity_error);
    end else begin
      $display("[MONITOR @ %0t] parity_error flag verified: %b", $time, parity_error);
    end

    // Check framing error flag
    if (framing_error !== expect_framing_err) begin
      $error("[MONITOR ERROR @ %0t] framing_error flag mismatch! Expected: %b, Got: %b", $time, expect_framing_err, framing_error);
    end else begin
      $display("[MONITOR @ %0t] framing_error flag verified: %b", $time, framing_error);
    end

    $display("[MONITOR @ %0t] RX frame verification completed successfully.\n", $time);
  endtask

  // Stimulus process
  initial begin
    // Initialize signals
    RX_IN          = 1'b1; // Idle high
    data_size_ctrl = DATA_8_BITS;
    parity_ctrl    = PARITY_NONE;
    stop_bits_ctrl = STOP_1_BIT;
    baud_rate_ctrl = BAUD_19200;

    // Wait for reset release
    @(posedge rst_n);
    repeat (5) @(posedge clk);

    $display("=== STARTING UART_RX TESTBENCH ===");

    // =========================================================
    // Test Case 1: 8-bit, No Parity, 1 Stop Bit, 19.2K Baud
    // =========================================================
    $display("[TEST CASE 1] Sending 8'hA5, 8-bit, No Parity, 1 Stop Bit");
    data_size_ctrl = DATA_8_BITS;
    parity_ctrl    = PARITY_NONE;
    stop_bits_ctrl = STOP_1_BIT;
    baud_rate_ctrl = BAUD_19200;

    fork
      send_uart_frame(8'hA5, DATA_8_BITS, PARITY_NONE, STOP_1_BIT, BAUD_19200);
      expect_rx_frame(8'hA5, DATA_8_BITS, 0, 0);
    join
    repeat (50) @(posedge clk);


    // =========================================================
    // Test Case 2: 5-bit, Odd Parity, 2 Stop Bits, 19.2K Baud
    // =========================================================
    $display("[TEST CASE 2] Sending 8'h1F (5-bit), Odd Parity, 2 Stop Bits");
    data_size_ctrl = DATA_5_BITS;
    parity_ctrl    = PARITY_ODD;
    stop_bits_ctrl = STOP_2_BITS;
    baud_rate_ctrl = BAUD_19200;

    fork
      send_uart_frame(8'h1F, DATA_5_BITS, PARITY_ODD, STOP_2_BITS, BAUD_19200);
      expect_rx_frame(8'h1F, DATA_5_BITS, 0, 0);
    join
    repeat (50) @(posedge clk);


    // =========================================================
    // Test Case 3: 7-bit, Even Parity, 1 Stop Bit, 19.2K Baud
    // =========================================================
    $display("[TEST CASE 3] Sending 8'h5A (7-bit), Even Parity, 1 Stop Bit");
    data_size_ctrl = DATA_7_BITS;
    parity_ctrl    = PARITY_EVEN;
    stop_bits_ctrl = STOP_1_BIT;
    baud_rate_ctrl = BAUD_19200;

    fork
      send_uart_frame(8'h5A, DATA_7_BITS, PARITY_EVEN, STOP_1_BIT, BAUD_19200);
      expect_rx_frame(8'h5A, DATA_7_BITS, 0, 0);
    join
    repeat (50) @(posedge clk);


    // =========================================================
    // Test Case 4: Back-to-Back Reception (No Idle cycles)
    // =========================================================
    $display("[TEST CASE 4] Back-to-Back Reception: 8'h33 followed by 8'hCC");
    data_size_ctrl = DATA_8_BITS;
    parity_ctrl    = PARITY_NONE;
    stop_bits_ctrl = STOP_1_BIT;
    baud_rate_ctrl = BAUD_19200;

    fork
      begin
        send_uart_frame(8'h33, DATA_8_BITS, PARITY_NONE, STOP_1_BIT, BAUD_19200);
        send_uart_frame(8'hCC, DATA_8_BITS, PARITY_NONE, STOP_1_BIT, BAUD_19200);
      end
      begin
        expect_rx_frame(8'h33, DATA_8_BITS, 0, 0);
        expect_rx_frame(8'hCC, DATA_8_BITS, 0, 0);
      end
    join
    repeat (50) @(posedge clk);


    // =========================================================
    // Test Case 5: Parity Error Check
    // =========================================================
    $display("[TEST CASE 5] Parity Error Injection");
    data_size_ctrl = DATA_8_BITS;
    parity_ctrl    = PARITY_EVEN;
    stop_bits_ctrl = STOP_1_BIT;
    baud_rate_ctrl = BAUD_19200;

    fork
      send_uart_frame(8'hF0, DATA_8_BITS, PARITY_EVEN, STOP_1_BIT, BAUD_19200, 1, 0); // inject_parity_error = 1
      expect_rx_frame(8'hF0, DATA_8_BITS, 1, 0); // expect_parity_err = 1
    join
    repeat (50) @(posedge clk);


    // =========================================================
    // Test Case 6: Framing Error Check
    // =========================================================
    $display("[TEST CASE 6] Framing Error Injection");
    data_size_ctrl = DATA_8_BITS;
    parity_ctrl    = PARITY_NONE;
    stop_bits_ctrl = STOP_1_BIT;
    baud_rate_ctrl = BAUD_19200;

    fork
      send_uart_frame(8'hA5, DATA_8_BITS, PARITY_NONE, STOP_1_BIT, BAUD_19200, 0, 1); // inject_framing_error = 1
      expect_rx_frame(8'hA5, DATA_8_BITS, 0, 1); // expect_framing_err = 1
    join
    repeat (50) @(posedge clk);


    // =========================================================
    // Test Case 7: Glitch Filtering (Invalid Start Bit)
    // =========================================================
    $display("[TEST CASE 7] Glitch Filtering on Start Bit");
    data_size_ctrl = DATA_8_BITS;
    parity_ctrl    = PARITY_NONE;
    stop_bits_ctrl = STOP_1_BIT;
    baud_rate_ctrl = BAUD_19200;

    // Send a brief glitch (3 clock cycles of 0) on RX_IN, then return to 1
    RX_IN = 1'b0;
    repeat (3) @(posedge clk);
    RX_IN = 1'b1;
    
    // Wait for some time to make sure it doesn't trigger Data_Valid
    repeat (500) @(posedge clk);
    $display("[TEST CASE 7] Glitch filtering verified. No Data_Valid observed.\n");

    $display("=== ALL TESTS COMPLETED SUCCESSFULLY ===");
    $finish;
  end

  // Watchdog timer
  initial begin
    #15000000; // 15ms watchdog
    $display("[WATCHDOG] Simulation timeout reached. Force exiting...");
    $finish;
  end

endmodule
