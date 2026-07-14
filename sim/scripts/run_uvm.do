# Create work library if not exists
if [file exists work] {
  vdel -all
}
vlib work

# Compile with code coverage enabled (statement, branch, condition, expression, finite state machine)
vlog -cover sbcef -f sim/listfiles/flist_uvm.f

# Set defaults
set test_name "uart_loopback_test"
set verbosity "UVM_MEDIUM"

# Parse arguments passed to "do run_uvm.do <test_name> <verbosity>"
if { [info exists 1] } {
  set test_name $1
}
if { [info exists 2] } {
  set verbosity $2
}

echo "=========================================================="
echo " UVM simulation run details:"
echo " Test Name : $test_name"
echo " Verbosity : $verbosity"
echo " Batch Mode: [batch_mode]"
echo "=========================================================="

# Start simulation with coverage and optimization visibility (+acc)
vsim -coverage -voptargs="+acc" -onfinish stop work.uart_tb_uvm_top +UVM_TESTNAME=$test_name +UVM_VERBOSITY=$verbosity

# Enable wave logging
log -r /*

# Check mode and execute accordingly
if { [batch_mode] } {
  run -all
  # Create directory if it does not exist
  file mkdir "sim/coverage/${test_name}"
  # Write coverage report to text file
  coverage report -detail -cvg -file "sim/coverage/${test_name}/cov_${test_name}.txt"
  # Save coverage database
  coverage save "sim/coverage/${test_name}/cov_${test_name}.ucdb"
  quit -f
} else {
  if [file exists sim/scripts/wave.do] {
    do sim/scripts/wave.do
  } else {
    add wave -r /*
  }
  run -all
}
