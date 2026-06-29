#!/bin/bash
# Run simulation in CLI mode (command line interface) and exit
vsim -c -do "do sim/scripts/run.do; run -all; quit"
