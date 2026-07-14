#!/bin/bash
# ==============================================================================
# UVM Regression & Coverage Merge Script
# ==============================================================================
# This script runs all UVM tests sequentially, checks logs for errors, merges 
# coverage databases, and generates unified coverage reports.

TESTS=(
  "uart_reg_access_test"
  "uart_loopback_test"
  "uart_overrun_test"
  "uart_rand_test"
  "uart_illegal_rand_test"
)

# Clean up old database files and logs
echo "=== Cleaning old databases and logs ==="
rm -rf sim/logs/
rm -rf sim/coverage/
rm -f transcript vsim.wlf

# Create directories
mkdir -p sim/logs
mkdir -p sim/coverage/regression

# Array to store results
declare -A TEST_STATUS

echo "=== Starting UVM Regression Run ==="
echo "--------------------------------------------------"

for test in "${TESTS[@]}"; do
  echo "Running test: $test..."
  
  # Run the UVM test via CLI and direct output to sim/logs/
  ./run_uvm_cli.sh "$test" > "sim/logs/${test}.log" 2>&1
  
  # Verify if test passed by scanning the log for UVM_ERROR and UVM_FATAL
  # (excluding summary lines which report "UVM_ERROR :    0")
  ERRORS=$(grep "UVM_ERROR" "sim/logs/${test}.log" | grep -v -E "UVM_ERROR :[[:space:]]+0" | wc -l)
  FATALS=$(grep "UVM_FATAL" "sim/logs/${test}.log" | grep -v -E "UVM_FATAL :[[:space:]]+0" | wc -l)
  WARNINGS=$(grep "UVM_WARNING" "sim/logs/${test}.log" | grep -v -E "UVM_WARNING :[[:space:]]+0" | wc -l)
  
  # Also check if transcript file exists and contains fatal/error
  if [ -f transcript ]; then
    ERRORS_TRANS=$(grep "UVM_ERROR" transcript | grep -v -E "UVM_ERROR :[[:space:]]+0" | wc -l)
    FATALS_TRANS=$(grep "UVM_FATAL" transcript | grep -v -E "UVM_FATAL :[[:space:]]+0" | wc -l)
    ERRORS=$((ERRORS + ERRORS_TRANS))
    FATALS=$((FATALS + FATALS_TRANS))
    # Move transcript to sim/logs/
    mv transcript "sim/logs/${test}_transcript.log"
  fi
  
  if [ "$ERRORS" -eq 0 ] && [ "$FATALS" -eq 0 ]; then
    TEST_STATUS["$test"]="PASSED"
    echo "Result: PASSED ($WARNINGS warnings)"
  else
    TEST_STATUS["$test"]="FAILED ($ERRORS errors, $FATALS fatals)"
    echo "Result: FAILED ($ERRORS errors, $FATALS fatals)"
  fi
  echo "--------------------------------------------------"
done

# Check if any UCDB databases were created
UCDB_FILES=(sim/coverage/*/cov_*.ucdb)
if [ ! -e "${UCDB_FILES[0]}" ]; then
  echo "Error: No coverage databases found under sim/coverage/. Regression failed."
  exit 1
fi

echo "=== Merging Coverage Databases ==="
# Merge all generated UCDB databases into merged_cov.ucdb inside sim/coverage/regression
vcover merge sim/coverage/regression/merged_cov.ucdb sim/coverage/*/cov_*.ucdb

if [ -f sim/coverage/regression/merged_cov.ucdb ]; then
  echo "Merge Successful -> sim/coverage/regression/merged_cov.ucdb created."
  echo "=== Generating Coverage Reports ==="
  
  # Generate detailed text report
  vcover report -detail -cvg -file sim/coverage/regression/merged_coverage_report.txt sim/coverage/regression/merged_cov.ucdb
else
  echo "Error: Failed to merge coverage databases."
fi

# Print final regression report summary table
echo ""
echo "=========================================================================="
echo "                           REGRESSION REPORT SUMMARY                      "
echo "=========================================================================="
printf "%-30s | %-10s\n" "Test Name" "Status"
echo "--------------------------------------------------------------------------"
for test in "${TESTS[@]}"; do
  printf "%-30s | %-10s\n" "$test" "${TEST_STATUS[$test]}"
done
echo "=========================================================================="

# Grep for final functional coverage score if text report exists
if [ -f sim/coverage/regression/merged_coverage_report.txt ]; then
  echo "Unified Functional Coverage Summary:"
  grep -A 1 "Covergroup Coverage" sim/coverage/regression/merged_coverage_report.txt
fi
echo "=========================================================================="
