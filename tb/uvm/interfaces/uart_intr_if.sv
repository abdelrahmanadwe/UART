`timescale 1ns/1ps

interface uart_intr_if;
  logic irq_tx_ready;
  logic irq_tx_done;
  logic irq_rx_done;
  logic irq_rx_parity;
  logic irq_rx_framing;
  logic irq_rx_overrun;
  logic irq;
endinterface
