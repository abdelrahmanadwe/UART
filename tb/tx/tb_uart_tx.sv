`timescale 1ns/1ps

import uart_defs::*;

module tb_uart_tx;

  // Clock & Reset
  logic        clk;
  logic        rst_n;
  logic        clk_en;

  // DUT IOs
  logic [7:0]  P_DATA;
  logic        Data_Valid;
  data_size_e  data_size_ctrl;
  parity_ctrl_e parity_ctrl;
  stop_bits_e  stop_bits_ctrl;
  baud_rate_e  baud_rate_ctrl;
  logic        TX_OUT;
  logic        ready;
  logic        tx_done;

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

  // Connect clk_en to the internal clk_en of the DUT
  assign clk_en = u_dut.clk_en;

  // Instantiate DUT
  uart_tx u_dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .P_DATA         (P_DATA),
    .Data_Valid     (Data_Valid),
    .data_size_ctrl (data_size_ctrl),
    .parity_ctrl    (parity_ctrl),
    .stop_bits_ctrl (stop_bits_ctrl),
    .baud_rate_ctrl (baud_rate_ctrl),
    .TX_OUT         (TX_OUT),
    .ready          (ready),
    .tx_done        (tx_done)
  );

  // Handshake protocol assertions (User requested valid-ready handshake constraints)
  // 1. Data_Valid once asserted cannot drop until ready goes high
  always @(posedge clk) begin
    if (rst_n && $past(rst_n) && $past(Data_Valid) && !$past(ready)) begin
      assert(Data_Valid === 1'b1) else $error("[Protocol Assertion Violation] Data_Valid went low before ready went high!");
    end
  end

  // 2. Data inputs and control configurations must remain stable while Data_Valid is asserted and ready is low
  always @(posedge clk) begin
    if (rst_n && $past(rst_n) && $past(Data_Valid) && !$past(ready)) begin
      assert(P_DATA === $past(P_DATA)) else $error("[Protocol Assertion Violation] P_DATA changed before ready went high!");
      assert(data_size_ctrl === $past(data_size_ctrl)) else $error("[Protocol Assertion Violation] data_size_ctrl changed before ready went high!");
      assert(parity_ctrl === $past(parity_ctrl)) else $error("[Protocol Assertion Violation] parity_ctrl changed before ready went high!");
      assert(stop_bits_ctrl === $past(stop_bits_ctrl)) else $error("[Protocol Assertion Violation] stop_bits_ctrl changed before ready went high!");
      assert(baud_rate_ctrl === $past(baud_rate_ctrl)) else $error("[Protocol Assertion Violation] baud_rate_ctrl changed before ready went high!");
    end
  end

  // Debug trace
  always @(posedge clk) begin
    if ($time >= 58000 && $time <= 76000) begin
      $display("[DEBUG @ %0t] state=%s (%b), clk_en=%b, ready=%b, Data_Valid=%b, TX_OUT=%b, next_state=%s (%b)", 
               $time, u_dut.u_fsm.state.name(), u_dut.u_fsm.state, clk_en, ready, Data_Valid, TX_OUT, u_dut.u_fsm.next_state.name(), u_dut.u_fsm.next_state);
    end
  end

  // Monitor Task to check the correctness of transmitted frame
  task automatic monitor_tx(
    input [7:0] expected_data,
    input data_size_e size,
    input parity_ctrl_e parity,
    input stop_bits_e stop
  );
    logic [7:0] rx_data;
    logic rx_parity;
    int num_data_bits;
    logic expected_parity;
    logic calculated_parity;

    case (size)
      DATA_5_BITS: num_data_bits = 5;
      DATA_6_BITS: num_data_bits = 6;
      DATA_7_BITS: num_data_bits = 7;
      DATA_8_BITS: num_data_bits = 8;
    endcase

    // 1. Wait for start bit (TX_OUT drops to 0)
    @(negedge TX_OUT);
    $display("[MONITOR @ %0t] Negedge on TX_OUT: Start bit detected.", $time);
    
    // 2. Sample Start Bit on clk_en pulse
    @(posedge clk iff clk_en);
    if (TX_OUT !== 1'b0) begin
      $error("[MONITOR ERROR @ %0t] Start bit is not 0! Got %b", $time, TX_OUT);
    end else begin
      $display("[MONITOR @ %0t] Start bit verified (0).", $time);
    end

    // 3. Sample Data Bits
    rx_data = 8'b0;
    for (int i = 0; i < num_data_bits; i++) begin
      @(posedge clk iff clk_en);
      rx_data[i] = TX_OUT;
      $display("[MONITOR @ %0t] Sampled Data Bit %0d: %b", $time, i, TX_OUT);
    end

    // Verify Data matches
    for (int i = num_data_bits; i < 8; i++) rx_data[i] = 1'b0;
    if (rx_data !== (expected_data & ((8'h01 << num_data_bits) - 1))) begin
      $error("[MONITOR ERROR @ %0t] Data mismatch! Expected: %b, Got: %b", $time, expected_data & ((8'h01 << num_data_bits) - 1), rx_data);
    end else begin
      $display("[MONITOR @ %0t] Data match verified: %h", $time, rx_data);
    end

    // 4. Sample Parity Bit (if enabled)
    if (parity == PARITY_ODD || parity == PARITY_EVEN) begin
      @(posedge clk iff clk_en);
      rx_parity = TX_OUT;
      
      case (size)
        DATA_5_BITS: calculated_parity = ^rx_data[4:0];
        DATA_6_BITS: calculated_parity = ^rx_data[5:0];
        DATA_7_BITS: calculated_parity = ^rx_data[6:0];
        DATA_8_BITS: calculated_parity = ^rx_data[7:0];
      endcase
      expected_parity = (parity == PARITY_ODD) ? ~calculated_parity : calculated_parity;

      if (rx_parity !== expected_parity) begin
        $error("[MONITOR ERROR @ %0t] Parity bit mismatch! Expected: %b, Got: %b", $time, expected_parity, rx_parity);
      end else begin
        $display("[MONITOR @ %0t] Parity bit verified: %b", $time, rx_parity);
      end
    end

    // 5. Sample Stop Bit(s)
    @(posedge clk iff clk_en);
    if (TX_OUT !== 1'b1) begin
      $error("[MONITOR ERROR @ %0t] Stop bit 1 mismatch! Expected: 1, Got: %b", $time, TX_OUT);
    end else begin
      $display("[MONITOR @ %0t] Stop bit 1 verified.", $time);
    end

    if (stop == STOP_2_BITS) begin
      @(posedge clk iff clk_en);
      if (TX_OUT !== 1'b1) begin
        $error("[MONITOR ERROR @ %0t] Stop bit 2 mismatch! Expected: 1, Got: %b", $time, TX_OUT);
      end else begin
        $display("[MONITOR @ %0t] Stop bit 2 verified.", $time);
      end
    end

    $display("[MONITOR @ %0t] Frame transaction completed successfully.\n", $time);
  endtask

  // Stimulus process
  initial begin
    // Initialize signals
    P_DATA         <= 8'b0;
    Data_Valid     <= 1'b0;
    data_size_ctrl <= DATA_8_BITS;
    parity_ctrl    <= PARITY_NONE;
    stop_bits_ctrl <= STOP_1_BIT;
    baud_rate_ctrl <= BAUD_19200;

    // Wait for reset release
    @(posedge rst_n);
    repeat (5) @(posedge clk);

    $display("=== STARTING UART_TX TESTBENCH ===");

    // ==========================================
    // Test Case 1: 8-bit, No Parity, 1 Stop Bit
    // ==========================================
    $display("[TEST CASE 1] Sending 8'hA5, 8-bit, No Parity, 1 Stop Bit");
    wait(ready == 1'b1);
    @(posedge clk);
    P_DATA         <= 8'hA5;
    Data_Valid     <= 1'b1;
    data_size_ctrl <= DATA_8_BITS;
    parity_ctrl    <= PARITY_NONE;
    stop_bits_ctrl <= STOP_1_BIT;
    baud_rate_ctrl <= BAUD_19200;
    
    @(posedge clk);
    Data_Valid     <= 1'b0; // Deassert valid
    
    // Spawn monitor in parallel
    monitor_tx(8'hA5, DATA_8_BITS, PARITY_NONE, STOP_1_BIT);

    // Wait for tx_done
    @(posedge tx_done);
    $display("[TEST CASE 1] tx_done pulse observed.\n");
    repeat (20) @(posedge clk);


    // ==========================================
    // Test Case 2: 5-bit, Odd Parity, 2 Stop Bits
    // ==========================================
    $display("[TEST CASE 2] Sending 8'h1F, 5-bit, Odd Parity, 2 Stop Bits");
    wait(ready == 1'b1);
    @(posedge clk);
    P_DATA         <= 8'h1F; // Only lower 5 bits (5'h1F = 5'b11111) are active
    Data_Valid     <= 1'b1;
    data_size_ctrl <= DATA_5_BITS;
    parity_ctrl    <= PARITY_ODD; // Expected Parity: ~^(5'b11111) = ~1 = 0
    stop_bits_ctrl <= STOP_2_BITS;
    baud_rate_ctrl <= BAUD_19200;

    @(posedge clk);
    Data_Valid     <= 1'b0;

    monitor_tx(8'h1F, DATA_5_BITS, PARITY_ODD, STOP_2_BITS);
    @(posedge tx_done);
    $display("[TEST CASE 2] tx_done pulse observed.\n");
    repeat (20) @(posedge clk);


    // ==========================================
    // Test Case 3: 7-bit, Even Parity, 1 Stop Bit
    // ==========================================
    $display("[TEST CASE 3] Sending 8'h5A, 7-bit, Even Parity, 1 Stop Bit");
    wait(ready == 1'b1);
    @(posedge clk);
    P_DATA         <= 8'h5A; // Lower 7 bits (7'h5A = 7'b1011010) -> 4 ones -> Even parity is 0
    Data_Valid     <= 1'b1;
    data_size_ctrl <= DATA_7_BITS;
    parity_ctrl    <= PARITY_EVEN;
    stop_bits_ctrl <= STOP_1_BIT;
    baud_rate_ctrl <= BAUD_19200;

    @(posedge clk);
    Data_Valid     <= 1'b0;

    monitor_tx(8'h5A, DATA_7_BITS, PARITY_EVEN, STOP_1_BIT);
    @(posedge tx_done);
    $display("[TEST CASE 3] tx_done pulse observed.\n");
    repeat (20) @(posedge clk);


    // =========================================================
    // Test Case 4: Back-to-Back Transmission (No Idle cycles)
    // 8-bit, No Parity, 1 Stop Bit
    // =========================================================
    $display("[TEST CASE 4] Back-to-Back transmission: 8'h33 followed by 8'hCC");
    wait(ready == 1'b1);
    @(posedge clk);
    P_DATA         <= 8'h33;
    Data_Valid     <= 1'b1;
    data_size_ctrl <= DATA_8_BITS;
    parity_ctrl    <= PARITY_NONE;
    stop_bits_ctrl <= STOP_1_BIT;
    baud_rate_ctrl <= BAUD_19200;

    // Spawn first monitor in parallel
    fork
      monitor_tx(8'h33, DATA_8_BITS, PARITY_NONE, STOP_1_BIT);
    join_none

    @(posedge clk);
    Data_Valid     <= 1'b0;

    // Wait until ready goes low (first transfer starts)
    wait(ready == 1'b0);
    // Wait until ready goes high again (during STOP bit of the first transfer)
    wait(ready == 1'b1);
    P_DATA         <= 8'hCC;
    Data_Valid     <= 1'b1;
    data_size_ctrl <= DATA_8_BITS;
    parity_ctrl    <= PARITY_NONE;
    stop_bits_ctrl <= STOP_1_BIT;
    baud_rate_ctrl <= BAUD_19200;

    // Spawn second monitor in parallel
    fork
      monitor_tx(8'hCC, DATA_8_BITS, PARITY_NONE, STOP_1_BIT);
    join_none
    
    // Wait until the handshake is complete (signaled by tx_done of the first transfer)
    wait(tx_done == 1'b1);
    Data_Valid     <= 1'b0;

    // Wait for the second frame to be fully completed (tx_done of the second transfer)
    @(posedge tx_done);
    $display("[TEST CASE 4] Back-to-back finished.\n");
    repeat (30) @(posedge clk);

    $display("=== ALL TESTS COMPLETED ===");
    $finish;
  end

  // Watchdog timer (increased for real baud rate generators at 50MHz clock)
  initial begin
    #10000000; // 10ms simulation limit
    $display("[WATCHDOG] Simulation timeout reached. Force exiting...");
    $finish;
  end

endmodule
