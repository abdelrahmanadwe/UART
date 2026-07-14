#!/bin/bash
# Usage: ./run_uvm_cli.sh [test_name] [verbosity]
# Examples:
#   ./run_uvm_cli.sh uart_rand_test UVM_HIGH
#   ./run_uvm_cli.sh uart_loopback_test UVM_MEDIUM

TEST_NAME=${1:-uart_loopback_test}
VERBOSITY=${2:-UVM_MEDIUM}

echo "=== Running UVM Test: $TEST_NAME with Verbosity: $VERBOSITY in CLI mode ==="
vsim -c -do "do sim/scripts/run_uvm.do $TEST_NAME $VERBOSITY"
