#!/bin/bash
# Run UVM simulation in CLI mode and quit.
# Usage: ./run_uvm_cli.sh [test_name] (default: uart_loopback_test)

TEST_NAME=${1:-uart_loopback_test}

echo "=== Running UVM Test: $TEST_NAME in CLI mode ==="
vsim -c -do "do sim/scripts/run_uvm.do; vsim -voptargs=\"+acc\" uart_tb_uvm_top +UVM_TESTNAME=$TEST_NAME; log -r /*; run -all; quit"
