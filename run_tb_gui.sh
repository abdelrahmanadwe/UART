#!/bin/bash
# Run simulation in GUI mode and keep the waveform viewer open
vsim -do "do sim/scripts/run.do; run -all"
