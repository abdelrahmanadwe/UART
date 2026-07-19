package uart_uvm_pkg;
  import uvm_pkg::*;
  import uart_defs::*;

  `include "uvm_macros.svh"

  // 1. APB Agent files
  `include "apb_agent/apb_agent_config.sv"
  `include "apb_agent/apb_seq_item.sv"
  typedef uvm_sequencer #(apb_seq_item) apb_sequencer;
  `include "apb_agent/apb_driver.sv"
  `include "apb_agent/apb_monitor.sv"
  `include "apb_agent/apb_agent.sv"

  // 2. UART Serial Agent files
  `include "uart_agent/uart_agent_config.sv"
  `include "uart_agent/uart_seq_item.sv"
  typedef uvm_sequencer #(uart_seq_item) uart_sequencer;
  `include "uart_agent/uart_driver.sv"
  `include "uart_agent/uart_monitor.sv"
  `include "uart_agent/uart_agent.sv"

  // 3. Register Model
  `include "reg_model/reg2apb_adapter.sv"
  `include "reg_model/uart_reg_predictor.sv"
  `include "reg_model/uart_reg_block.sv"
  `include "uart_coverage.sv"

  // 4. Scoreboard
  `include "scoreboard.sv"

  // 5. Environment
  `include "env.sv"

  // 6. Sequences
  `include "seq/uart_base_seq.sv"
  `include "seq/uart_virtual_seqs.sv"

  // 7. Tests
  `include "tests/uart_base_test.sv"

endpackage
