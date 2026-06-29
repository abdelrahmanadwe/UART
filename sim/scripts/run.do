# Create work library
vlib work

# Compile design and testbench files using listfile (flist.f)
vlog -f sim/scripts/flist.f

# Load the simulation with access to internal signals
vsim -voptargs="+acc" tb_uart_top

# Log all signals for debugging
log -r /*

# Run custom styled wave configuration
do sim/scripts/wave.do
