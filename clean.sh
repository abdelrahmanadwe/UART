#!/bin/bash
# ==============================================================================
# Simulation Clean Script
# ==============================================================================
# Removes all compiled simulation work libraries, waveform database logs, 
# console log files, and coverage database folders under sim/.

echo "=== Cleaning simulation outputs, logs, and coverage under sim/ ==="
rm -rf sim/logs/
rm -rf sim/coverage/
rm -f transcript vsim.wlf *.log *.txt *.ucdb
rm -rf work/
echo "Clean complete! Repository is now clean."
