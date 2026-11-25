# Synchronous FIFO in Verilog

A parameterized, single-clock FIFO (first-in, first-out buffer) written in Verilog. The design stores incoming words and returns them in the same order when read requests are accepted.

## Features

- Configurable data width and FIFO depth.
- Independent read and write enables.
- `full`, `empty`, and occupancy (`count`) status outputs.
- Explicit pointer wrap-around, including non-power-of-two depths.
- Protection against writes while full and reads while empty.
- Correct occupancy handling when read and write are accepted in the same cycle.
- Registered read data output; `data_out` changes only after an accepted read.
- Self-checking testbench with a software reference model.

## Architecture

![Synchronous FIFO architecture](docs/fifo_architecture.svg)

The FIFO uses one write pointer and one read pointer. Both pointers operate on the rising edge of the same clock. The occupancy counter tracks the number of stored words and drives the status flags. Each pointer wraps explicitly at `DEPTH - 1`; this avoids relying on binary overflow and allows non-power-of-two depths such as 5.

## Example instantiation

```verilog
sync_fifo #(
    .DATA_WIDTH(8),
    .DEPTH(16)
) fifo_inst (
    .clk(clk),
    .rst(rst),
    .wr_en(wr_en),
    .rd_en(rd_en),
    .data_in(data_in),
    .data_out(data_out),
    .full(full),
    .empty(empty),
    .count(count)
);
```

## Interface

| Signal | Direction | Description |
|---|---|---|
| `clk` | Input | Common clock; operations occur on its rising edge. |
| `rst` | Input | Synchronous, active-high reset. |
| `wr_en` | Input | Requests a write when the FIFO is not full. |
| `rd_en` | Input | Requests a read when the FIFO is not empty. |
| `data_in` | Input | Word to be stored on an accepted write. |
| `data_out` | Output | Registered word from the last accepted read. |
| `full` | Output | High when `count == DEPTH`. |
| `empty` | Output | High when `count == 0`. |
| `count` | Output | Number of words currently stored. |

### Parameters

| Parameter | Default | Description |
|---|---:|---|
| `DATA_WIDTH` | 8 | Number of bits in each stored word. |
| `DEPTH` | 16 | Number of words the FIFO can hold. Must be at least 1. |
| `ADDR_WIDTH` | Derived | Pointer width, derived from `DEPTH`. |
| `COUNT_WIDTH` | Derived | Occupancy counter width, derived from `DEPTH`. |

`ADDR_WIDTH` and `COUNT_WIDTH` are derived by default. They can be overridden if a particular integration requires it, but the values must be wide enough for the selected depth.

## Design decisions

- The design uses a single clock for both sides; this keeps the control logic synchronous and avoids clock-domain crossing logic in this project.
- The pointers wrap explicitly at the configured depth, so a depth of 5 works as well as a depth of 8 or 16.
- `count` is the source of truth for `full` and `empty`. It increments when only a write is accepted, decrements when only a read is accepted, and holds when both or neither operation is accepted.
- The read output is registered. There is no fall-through path from `data_in` to `data_out`.

## Read and write behavior

A request is accepted only when its corresponding status condition allows it:

- Write accepted: `wr_en && !full`
- Read accepted: `rd_en && !empty`

When both operations are accepted on the same rising clock edge, one word is written and one word is read, so `count` does not change. At full capacity, a simultaneous read/write request accepts the read but rejects the write because `full` was asserted before the edge. When empty, a simultaneous request accepts the write but rejects the read. The newly written word can be read on a later clock edge.

The memory array is not cleared by reset. Reset clears the pointers, occupancy counter, and output register; while `empty` is high, memory contents are not valid FIFO data.

## Repository layout

```text
synchronous-fifo-verilog/
├── rtl/
│   └── sync_fifo.v
├── tb/
│   └── tb_sync_fifo.v
├── scripts/
│   ├── run_sim.sh
│   └── run_sim.bat
├── docs/
│   ├── fifo_architecture.svg
│   └── verification_plan.md
├── .github/workflows/
│   └── rtl-simulation.yml
├── .gitignore
├── LICENSE
└── README.md
```

## Run the simulation

The testbench uses Icarus Verilog and writes VCD waveform files for GTKWave.

### Linux / macOS / WSL

Install Icarus Verilog, then run:

```bash
chmod +x scripts/run_sim.sh
./scripts/run_sim.sh
```

### Windows

Install Icarus Verilog and make sure `iverilog.exe` and `vvp.exe` are on `PATH`. Run:

```bat
scripts\run_sim.bat
```

The script compiles and runs the testbench at depths 8 and 5. The second configuration checks pointer wrap-around with a non-power-of-two depth. Successful runs print a `PASS` line for each configuration. Waveforms are written to `build/`.

### View a waveform

Open either VCD file with GTKWave:

```bash
gtkwave build/sync_fifo_depth8.vcd
```

Useful signals to inspect are `wr_en`, `rd_en`, `data_in`, `data_out`, `full`, `empty`, `count`, `write_ptr`, and `read_ptr` (the pointers are inside the DUT hierarchy).

## Verification coverage

The testbench checks reset, read requests while empty, filling to capacity, rejected writes while full, FIFO ordering while draining, simultaneous read/write operation, pointer wrap-around, and mixed read/write traffic. A small software model checks the output data, occupancy, and status flags after every cycle.

See [the verification plan](docs/verification_plan.md) for the individual cases.

## Design limits

- This is a synchronous FIFO: read and write operations use the same clock.
- The read data is registered and appears after the rising edge on which a read is accepted.
- This implementation is intended for RTL simulation and synthesis as a small memory/register-based FIFO. A target FPGA or ASIC flow may infer a different memory structure depending on its synthesis settings.
- This project does not claim timing closure or physical implementation results for a particular device.

## License

MIT. See [LICENSE](LICENSE).
