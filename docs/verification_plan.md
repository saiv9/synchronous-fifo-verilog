# Verification plan

The testbench instantiates the FIFO with an 8-bit data path and runs two configurations: depth 8 and depth 5. The depth-5 run checks that the pointer logic wraps at the configured depth rather than relying on binary overflow.

| Case | Stimulus | Expected result |
|---|---|---|
| Reset | Assert `rst` across a rising edge. | Pointers, `count`, and `data_out` clear; `empty=1`, `full=0`. |
| Read while empty | Assert `rd_en` when empty. | No read is accepted; occupancy remains zero. |
| Fill | Write exactly `DEPTH` words. | Occupancy increases to `DEPTH`; `full=1`. |
| Write while full | Request one additional write. | Request is ignored; occupancy and stored order do not change. |
| Drain | Read all stored words. | Words are returned in first-in, first-out order; `empty=1` at the end. |
| Read while empty after drain | Request another read. | Request is ignored; occupancy remains zero. |
| Simultaneous read/write | With two words stored, request both operations. | Oldest word is returned, new word is stored, and occupancy is unchanged. |
| Mixed traffic | Apply alternating write, read, and simultaneous requests. | Data order, occupancy, and status flags match the reference model. |
| Pointer wrap-around | Continue traffic past the end of the memory array. | Pointers return to index zero without accessing an invalid location. |

## Pass criteria

A run passes when the testbench reports `PASS` and no mismatch is printed for read data, occupancy, `full`, or `empty`.

## Manual waveform review

After simulation, open the generated VCD file in GTKWave. Confirm that accepted reads update `data_out` on the active clock edge, rejected requests do not move the corresponding pointer, and `count` changes only when exactly one operation is accepted.
