import uart_defs::*;

module baud_generator #(
  parameter int OVERSAMPLING = 1 // 1 for TX, 16 for RX
)(
  input  logic                  clk,
  input  logic                  rst_n,
  input  baud_rate_e            baud_rate_ctrl,
  input  logic                  active,
  output logic                  baud_out
);

  logic [15:0] max_count;
  logic [15:0] counter;

  always_comb begin
    case (baud_rate_ctrl)
      BAUD_2400:  max_count = 16'(32'd50000000 / (2400 * OVERSAMPLING));
      BAUD_4800:  max_count = 16'(32'd50000000 / (4800 * OVERSAMPLING));
      BAUD_9600:  max_count = 16'(32'd50000000 / (9600 * OVERSAMPLING));
      BAUD_19200: max_count = 16'(32'd50000000 / (19200 * OVERSAMPLING));
      BAUD_115200:max_count = 16'(32'd50000000 / (115200 * OVERSAMPLING));
      default:    max_count = 16'(32'd50000000 / (19200 * OVERSAMPLING));
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter  <= 16'd0;
      baud_out <= 1'b0;
    end else if (!active) begin
      counter  <= 16'd0;
      baud_out <= 1'b0;
    end else begin
      if (counter >= max_count - 16'd1) begin
        counter  <= 16'd0;
        baud_out <= 1'b1;
      end else begin
        counter  <= counter + 16'd1;
        baud_out <= 1'b0;
      end
    end
  end

endmodule
