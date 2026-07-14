#!/bin/bash
# Usage: ./run_uvm_gui.sh [test_name] [verbosity]
# Examples:
#   ./run_uvm_gui.sh uart_rand_test UVM_HIGH
#   ./run_uvm_gui.sh uart_loopback_test UVM_MEDIUM

TEST_NAME=${1:-uart_loopback_test}
VERBOSITY=${2:-UVM_MEDIUM}

echo "=== Running UVM Test: $TEST_NAME with Verbosity: $VERBOSITY in GUI mode ==="
vsim -do "do sim/scripts/run_uvm.do $TEST_NAME $VERBOSITY"
