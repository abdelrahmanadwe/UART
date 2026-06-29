class uart_driver extends uvm_driver #(uart_seq_item);
  `uvm_component_utils(uart_driver)

  virtual uart_serial_if vif;
  virtual apb_if        vif_apb; // Needed to get PCLK for timing
  uvm_analysis_port #(uart_seq_item) ap;

  function new(string name = "uart_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual uart_serial_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("UART_DRV", "Failed to get virtual interface vif from config DB")
    end
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif_apb", vif_apb)) begin
      `uvm_fatal("UART_DRV", "Failed to get virtual interface vif_apb from config DB")
    end
  endfunction

  task run_phase(uvm_phase phase);
    // Initialize rx_serial to idle (high)
    vif.rx_serial <= 1'b1;

    // Wait for reset release
    @(posedge vif_apb.PRESETn);

    forever begin
      seq_item_port.get_next_item(req);
      drive_serial_frame(req);
      ap.write(req);
      seq_item_port.item_done();
    end
  endtask

  // Helper function to return bit duration in clock cycles
  function int get_bit_cycles(baud_rate_e rate);
    case (rate)
      BAUD_2400:   return 20833;
      BAUD_4800:   return 10417;
      BAUD_9600:   return 5208;
      BAUD_19200:  return 2604;
      BAUD_115200: return 434;
      default:     return 2604;
    endcase
  endfunction

  task drive_serial_frame(uart_seq_item item);
    int bit_cycles;
    int num_bits;
    bit [7:0] active_data;
    bit parity_bit;

    bit_cycles = get_bit_cycles(item.baud_rate);

    case (item.data_size)
      DATA_5_BITS: begin active_data = item.data & 8'h1F; num_bits = 5; end
      DATA_6_BITS: begin active_data = item.data & 8'h3F; num_bits = 6; end
      DATA_7_BITS: begin active_data = item.data & 8'h7F; num_bits = 7; end
      DATA_8_BITS: begin active_data = item.data;         num_bits = 8; end
      default:     begin active_data = item.data;         num_bits = 8; end
    endcase

    // 1. Start Bit (Low)
    vif.rx_serial <= 1'b0;
    repeat (bit_cycles) @(posedge vif_apb.PCLK);

    // 2. Data Bits (LSB first)
    for (int i = 0; i < num_bits; i++) begin
      vif.rx_serial <= active_data[i];
      repeat (bit_cycles) @(posedge vif_apb.PCLK);
    end

    // 3. Parity Bit (Optional)
    if (item.parity_ctrl == PARITY_EVEN || item.parity_ctrl == PARITY_ODD) begin
      bit computed_parity;
      computed_parity = ^active_data;
      if (item.parity_ctrl == PARITY_ODD) begin
        computed_parity = ~computed_parity;
      end

      // Inject parity error if requested
      if (item.error_type == ERR_PARITY) begin
        vif.rx_serial <= ~computed_parity;
      end else begin
        vif.rx_serial <= computed_parity;
      end
      repeat (bit_cycles) @(posedge vif_apb.PCLK);
    end

    // 4. Stop Bits (High)
    // First stop bit
    if (item.error_type == ERR_FRAMING) begin
      vif.rx_serial <= 1'b0; // Force framing error
    end else begin
      vif.rx_serial <= 1'b1;
    end
    repeat (bit_cycles) @(posedge vif_apb.PCLK);

    // Second stop bit (if configured)
    if (item.stop_bits == STOP_2_BITS) begin
      vif.rx_serial <= 1'b1;
      repeat (bit_cycles) @(posedge vif_apb.PCLK);
    end
  endtask

endclass
