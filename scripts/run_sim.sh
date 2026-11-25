#!/usr/bin/env bash
set -euo pipefail

mkdir -p build

echo "Running FIFO test at depth 8"
iverilog -g2012 -Wall -s tb_sync_fifo -o build/fifo_depth8.vvp \
  rtl/sync_fifo.v tb/tb_sync_fifo.v
vvp build/fifo_depth8.vvp +VCD=build/sync_fifo_depth8.vcd | tee build/fifo_depth8.log

echo "Running FIFO test at depth 5"
iverilog -g2012 -Wall -s tb_sync_fifo -P tb_sync_fifo.FIFO_DEPTH=5 \
  -o build/fifo_depth5.vvp rtl/sync_fifo.v tb/tb_sync_fifo.v
vvp build/fifo_depth5.vvp +VCD=build/sync_fifo_depth5.vcd | tee build/fifo_depth5.log
