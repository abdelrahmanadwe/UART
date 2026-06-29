import uart_defs::*;

module uart_reg_file (
  // APB Standard Bus Interface
  input  logic                  PCLK,
  input  logic                  PRESETn,
  input  logic [4:0]            PADDR,
  input  logic                  PSEL,
  input  logic                  PENABLE,
  input  logic                  PWRITE,
  input  logic [31:0]           PWDATA,
  output logic                  PREADY,
  output logic [31:0]           PRDATA,
  output logic                  PSLVERR,

  // Hardware Status Inputs from RX/TX
  input  logic                  tx_ready_hw,
  input  logic                  tx_done_hw,
  input  logic [7:0]            rx_data_hw,
  input  logic                  rx_valid_hw,
  input  logic                  rx_parity_error_hw,
  input  logic                  rx_framing_error_hw,

  // Hardware Control Outputs to RX/TX
  output logic [7:0]            tx_data_hw,
  output logic                  tx_valid_hw,
  output data_size_e            data_size_ctrl,
  output parity_ctrl_e          parity_ctrl,
  output stop_bits_e            stop_bits_ctrl,
  output logic [15:0]           baud_div,
  output logic                  tx_enable_ctrl,
  output logic                  rx_enable_ctrl,

  // Interrupt Outputs (Masked)
  output logic                  irq_tx_ready,
  output logic                  irq_tx_done,
  output logic                  irq_rx_done,
  output logic                  irq_rx_parity,
  output logic                  irq_rx_framing,
  output logic                  irq_rx_overrun,
  output logic                  irq
);

  // APB Address Decodes (5-bit byte offset)
  localparam bit [4:0] ADDR_CFG       = 5'h00;
  localparam bit [4:0] ADDR_STATUS    = 5'h04;
  localparam bit [4:0] ADDR_INTR_RAW  = 5'h08;
  localparam bit [4:0] ADDR_INTR_EN   = 5'h0C;
  localparam bit [4:0] ADDR_INTR_MASK = 5'h10;
  localparam bit [4:0] ADDR_TX_DATA   = 5'h14;
  localparam bit [4:0] ADDR_RX_DATA   = 5'h18;
  localparam bit [4:0] ADDR_BAUD_DIV  = 5'h1C;

  // Generate internal write/read strobe signals
  // Side-effects should only occur during the APB ACCESS phase (PSEL & PENABLE)
  logic reg_write;
  logic reg_read;

  assign reg_write = PSEL && PENABLE && PWRITE;
  assign reg_read  = PSEL && PENABLE && !PWRITE;

  // Address validity check
  logic addr_valid;
  assign addr_valid = (PADDR == ADDR_CFG) ||
                      (PADDR == ADDR_STATUS) ||
                      (PADDR == ADDR_INTR_RAW) ||
                      (PADDR == ADDR_INTR_EN) ||
                      (PADDR == ADDR_INTR_MASK) ||
                      (PADDR == ADDR_TX_DATA) ||
                      (PADDR == ADDR_RX_DATA) ||
                      (PADDR == ADDR_BAUD_DIV);

  // Ready and Slave Error logic
  assign PREADY  = 1'b1; // Zero wait-states
  assign PSLVERR = PSEL && PENABLE && !addr_valid;

  // 1. Config Register (CFG)
  // [2:0]: Reserved/Unused
  // [4:3]: data_size_ctrl (Default: DATA_8_BITS = 2'b11)
  // [6:5]: parity_ctrl    (Default: PARITY_NONE = 2'b00)
  // [7]  : stop_bits_ctrl  (Default: STOP_1_BIT  = 1'b0)
  // [8]  : tx_enable_ctrl  (Default: 1'b0)
  // [9]  : rx_enable_ctrl  (Default: 1'b0)
  logic [9:0] cfg_reg;
  
  assign data_size_ctrl  = data_size_e'(cfg_reg[4:3]);
  assign parity_ctrl     = parity_ctrl_e'(cfg_reg[6:5]);
  assign stop_bits_ctrl  = stop_bits_e'(cfg_reg[7]);
  assign tx_enable_ctrl  = cfg_reg[8];
  assign rx_enable_ctrl  = cfg_reg[9];

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      cfg_reg <= 10'h18; // 8-bit, No Parity, 1 Stop, TX/RX Disabled
    end else if (reg_write && PADDR == ADDR_CFG) begin
      cfg_reg <= PWDATA[9:0];
    end
  end

  // 1b. Baud Divisor Register (BAUD_DIV)
  logic [15:0] baud_div_reg;
  assign baud_div = baud_div_reg;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      baud_div_reg <= 16'd163; // Default 19.2K Baud under 50MHz
    end else if (reg_write && PADDR == ADDR_BAUD_DIV) begin
      baud_div_reg <= PWDATA[15:0];
    end
  end

  // 2. Status Register (STATUS)
  // [0]: tx_ready (from hardware)
  // [1]: rx_valid_status (set by rx_valid_hw, cleared by reading RX_DATA)
  // [2]: dor_reg (Data Overrun, set when new rx data comes but rx_valid_status is still 1)
  logic rx_valid_status;
  logic dor_reg;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      rx_valid_status <= 1'b0;
    end else begin
      // Set when new data arrives, clear when RX_DATA register is read
      rx_valid_status <= (rx_valid_status | rx_valid_hw) & ~(reg_read && PADDR == ADDR_RX_DATA);
    end
  end

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      dor_reg <= 1'b0;
    end else begin
      if (rx_valid_hw && rx_valid_status && !(reg_read && PADDR == ADDR_RX_DATA)) begin
        dor_reg <= 1'b1;
      end else if (reg_read && PADDR == ADDR_RX_DATA) begin
        dor_reg <= 1'b0;
      end
    end
  end
  // TX buffer empty status for register interface (UDRE / transmit buffer empty)
  logic tx_pending;
  logic tx_ready_reg_file;
  assign tx_ready_reg_file = tx_ready_hw && !tx_pending;

  // 3. Raw Interrupt Register (INTR_RAW / RIS)
  // [0]: tx_done_raw
  // [1]: parity_error_raw
  // [2]: framing_error_raw
  // [3]: rx_done_raw
  // [4]: tx_ready_raw (Level-sensitive, reflecting tx_ready_hw status)
  // [5]: overrun_error_raw (Data Overrun)
  // Write-1-to-Clear (W1C) for bits [3:0] and [5]
  logic [5:0] intr_raw_reg;
  logic [4:0] intr_raw_latched;

  assign intr_raw_reg[3:0] = intr_raw_latched[3:0];
  assign intr_raw_reg[4]   = tx_ready_reg_file;
  assign intr_raw_reg[5]   = intr_raw_latched[4];

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      intr_raw_latched <= 5'b00000;
    end else begin
      // Latch hardware events and handle W1C
      // Bit 0: TX Done
      if (tx_done_hw) begin
        intr_raw_latched[0] <= 1'b1;
      end else if (reg_write && PADDR == ADDR_INTR_RAW && PWDATA[0]) begin
        intr_raw_latched[0] <= 1'b0;
      end

      // Bit 1: Parity Error
      if (rx_valid_hw && rx_parity_error_hw) begin
        intr_raw_latched[1] <= 1'b1;
      end else if (reg_write && PADDR == ADDR_INTR_RAW && PWDATA[1]) begin
        intr_raw_latched[1] <= 1'b0;
      end

      // Bit 2: Framing Error
      if (rx_valid_hw && rx_framing_error_hw) begin
        intr_raw_latched[2] <= 1'b1;
      end else if (reg_write && PADDR == ADDR_INTR_RAW && PWDATA[2]) begin
        intr_raw_latched[2] <= 1'b0;
      end

      // Bit 3: RX Done (set on rx_valid_hw, cleared on RX_DATA read or W1C)
      if (rx_valid_hw) begin
        intr_raw_latched[3] <= 1'b1;
      end else if ((reg_read && PADDR == ADDR_RX_DATA) || (reg_write && PADDR == ADDR_INTR_RAW && PWDATA[3])) begin
        intr_raw_latched[3] <= 1'b0;
      end

      // Bit 5: Overrun Error (set on overrun, cleared on RX_DATA read or W1C)
      if (rx_valid_hw && rx_valid_status && !(reg_read && PADDR == ADDR_RX_DATA)) begin
        intr_raw_latched[4] <= 1'b1;
      end else if ((reg_read && PADDR == ADDR_RX_DATA) || (reg_write && PADDR == ADDR_INTR_RAW && PWDATA[5])) begin
        intr_raw_latched[4] <= 1'b0;
      end
    end
  end

  // 4. Interrupt Enable Register (INTR_EN / IER)
  // [0]: tx_done_ie
  // [1]: parity_error_ie
  // [2]: framing_error_ie
  // [3]: rx_done_ie
  // [4]: tx_ready_ie
  // [5]: overrun_error_ie
  logic [5:0] intr_en_reg;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      intr_en_reg <= 6'b000000; // Disabled by default
    end else if (reg_write && PADDR == ADDR_INTR_EN) begin
      intr_en_reg <= PWDATA[5:0];
    end
  end

  // 5. Masked Interrupt Register (INTR_MASK / MIS)
  // Evaluated combinationally: RAW & EN
  logic [5:0] intr_mask_reg;
  assign intr_mask_reg = intr_raw_reg & intr_en_reg;

  // Interrupt Outputs to Top level
  assign irq_tx_ready    = intr_mask_reg[4];
  assign irq_tx_done     = intr_mask_reg[0];
  assign irq_rx_parity   = intr_mask_reg[1];
  assign irq_rx_framing  = intr_mask_reg[2];
  assign irq_rx_done     = intr_mask_reg[3];
  assign irq_rx_overrun  = intr_mask_reg[5];
  assign irq             = |intr_mask_reg;

  // 6. TX Data Register (TX_DATA)
  // Latches TX data and holds tx_valid_hw using a pending flag until accepted by hardware (tx_ready_hw goes low)
  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      tx_data_hw <= 8'h00;
      tx_pending <= 1'b0;
    end else begin
      if (reg_write && PADDR == ADDR_TX_DATA && tx_ready_reg_file && tx_enable_ctrl) begin
        tx_data_hw <= PWDATA[7:0];
        tx_pending <= 1'b1;
      end else if (tx_pending && !tx_ready_hw) begin
        tx_pending <= 1'b0;
      end
    end
  end

  assign tx_valid_hw = tx_pending;

  // 7. RX Data Register (RX_DATA)
  // Latches rx_data_hw from receiver when valid is asserted
  logic [7:0] rx_data_reg;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      rx_data_reg <= 8'h00;
    end else if (rx_valid_hw) begin
      rx_data_reg <= rx_data_hw;
    end
  end

  // Register File Read Bus
  always_comb begin
    case (PADDR)
      ADDR_CFG:       PRDATA = {22'b0, cfg_reg};
      ADDR_STATUS:    PRDATA = {29'b0, dor_reg, rx_valid_status, tx_ready_reg_file};
      ADDR_INTR_RAW:  PRDATA = {26'b0, intr_raw_reg};
      ADDR_INTR_EN:   PRDATA = {26'b0, intr_en_reg};
      ADDR_INTR_MASK: PRDATA = {26'b0, intr_mask_reg};
      ADDR_RX_DATA:   PRDATA = {24'b0, rx_data_reg};
      ADDR_BAUD_DIV:  PRDATA = {16'b0, baud_div_reg};
      default:        PRDATA = 32'b0;
    endcase
  end

endmodule
