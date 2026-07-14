`timescale 1ns/1ps

interface uart_intr_if (
  input logic clk,
  input logic rst_n
);
  logic irq_tx_ready;
  logic irq_tx_done;
  logic irq_rx_done;
  logic irq_rx_parity;
  logic irq_rx_framing;
  logic irq_rx_overrun;
  logic irq;

  // SVA: If any individual interrupt flag is raised, the main irq pin must also be raised
  property p_irq_assert;
    @(posedge clk) disable iff (!rst_n)
    (irq_tx_ready || irq_tx_done || irq_rx_done || irq_rx_parity || irq_rx_framing || irq_rx_overrun) |-> irq;
  endproperty

  assert property (p_irq_assert)
    else $error("[SVA_INTR_ERR] One or more individual interrupt flags are raised, but the global irq pin is low!");

endinterface
