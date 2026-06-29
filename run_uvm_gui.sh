#!/bin/bash
# Run UVM simulation in GUI mode and keep the waveform viewer open.
# Usage: ./run_uvm_gui.sh [test_name] (default: uart_loopback_test)

TEST_NAME=${1:-uart_loopback_test}

echo "=== Running UVM Test: $TEST_NAME in GUI mode ==="
vsim -do "do sim/scripts/run_uvm.do; vsim -voptargs=\"+acc\" uart_tb_uvm_top +UVM_TESTNAME=$TEST_NAME; log -r /*; run -all"
