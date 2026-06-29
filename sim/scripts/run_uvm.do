# Create work library
vlib work

# Compile design and UVM testbench files using flist_uvm.f
vlog +incdir+/home/abdelrahman-adwe/questasim/verilog_src/uvm-1.1d/src -f sim/listfiles/flist_uvm.f
