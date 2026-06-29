class uart_monitor extends uvm_monitor;
  `uvm_component_utils(uart_monitor)

  virtual uart_serial_if vif;
  virtual apb_if        vif_apb;
  
  // Handle to UVM Register Model (mirrored config values)
  uvm_reg_block         reg_model;

  uvm_analysis_port #(uart_seq_item) ap;

  function new(string name = "uart_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual uart_serial_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("UART_MON", "Failed to get virtual interface vif from config DB")
    end
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif_apb", vif_apb)) begin
      `uvm_fatal("UART_MON", "Failed to get virtual interface vif_apb from config DB")
    end
  endfunction

  task run_phase(uvm_phase phase);
    uart_seq_item item;
    data_size_e   size;
    parity_ctrl_e parity;
    stop_bits_e   stop;
    bit [15:0]    baud_div;
    int           bit_cycles;
    int           num_bits;

    @(posedge vif_apb.PRESETn);

    forever begin
      // Wait for start bit (falling edge on tx_serial)
      @(negedge vif.tx_serial);
      
      // Read current dynamic configuration
      get_config(size, parity, stop, baud_div);
      bit_cycles = int'(baud_div) * 16;
      
      case (size)
        DATA_5_BITS: num_bits = 5;
        DATA_6_BITS: num_bits = 6;
        DATA_7_BITS: num_bits = 7;
        DATA_8_BITS: num_bits = 8;
        default:     num_bits = 8;
      endcase

      // Wait 1.5 bit periods to sample first data bit (LSB)
      repeat (bit_cycles + (bit_cycles / 2)) @(posedge vif_apb.PCLK);

      item = uart_seq_item::type_id::create("item");
      item.data_size   = size;
      item.parity_ctrl = parity;
      item.stop_bits   = stop;
      item.baud_div    = baud_div;
      item.data        = 8'h0;
      item.error_type  = ERR_NONE;

      // Sample data bits
      for (int i = 0; i < num_bits; i++) begin
        item.data[i] = vif.tx_serial;
        repeat (bit_cycles) @(posedge vif_apb.PCLK);
      end

      // Sample parity bit (if enabled)
      if (parity == PARITY_EVEN || parity == PARITY_ODD) begin
        bit parity_sampled;
        bit parity_expected;
        parity_sampled = vif.tx_serial;
        parity_expected = ^item.data;
        if (parity == PARITY_ODD) begin
          parity_expected = ~parity_expected;
        end
        if (parity_sampled !== parity_expected) begin
          item.error_type = ERR_PARITY;
        end
        repeat (bit_cycles) @(posedge vif_apb.PCLK);
      end

      // Sample first stop bit
      if (vif.tx_serial !== 1'b1) begin
        item.error_type = ERR_FRAMING;
      end

      // Publish decoded transaction to scoreboard
      ap.write(item);
    end
  endtask

  function void get_config(output data_size_e size, output parity_ctrl_e parity, output stop_bits_e stop, output bit [15:0] baud_div);
    if (reg_model != null) begin
      uvm_reg cfg_reg_obj;
      uvm_reg div_reg_obj;
      cfg_reg_obj = reg_model.get_reg_by_name("cfg");
      div_reg_obj = reg_model.get_reg_by_name("baud_div");
      
      if (div_reg_obj != null) begin
        baud_div = div_reg_obj.get_mirrored_value();
      end else begin
        baud_div = 16'd163;
      end
      
      if (cfg_reg_obj != null) begin
        bit [31:0] cfg_val = cfg_reg_obj.get_mirrored_value();
        size   = data_size_e'(cfg_val[4:3]);
        parity = parity_ctrl_e'(cfg_val[6:5]);
        stop   = stop_bits_e'(cfg_val[7]);
      end else begin
        size   = DATA_8_BITS;
        parity = PARITY_NONE;
        stop   = STOP_1_BIT;
      end
    end else begin
      size   = DATA_8_BITS;
      parity = PARITY_NONE;
      stop   = STOP_1_BIT;
      baud_div = 16'd163;
    end
  endfunction

endclass
