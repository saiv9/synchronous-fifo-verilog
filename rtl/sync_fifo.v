`timescale 1ns/1ps

// Parameterized synchronous FIFO.
// Reset is synchronous and active high. data_out updates only on an accepted read.
module sync_fifo #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH = 16,
    parameter integer ADDR_WIDTH = (DEPTH <= 2) ? 1 : $clog2(DEPTH),
    parameter integer COUNT_WIDTH = $clog2(DEPTH + 1)
) (
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     wr_en,
    input  wire                     rd_en,
    input  wire [DATA_WIDTH-1:0]    data_in,
    output reg  [DATA_WIDTH-1:0]    data_out,
    output wire                     full,
    output wire                     empty,
    output reg  [COUNT_WIDTH-1:0]   count
);

    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] write_ptr;
    reg [ADDR_WIDTH-1:0] read_ptr;

    wire write_accepted;
    wire read_accepted;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    // Requests made while full or empty are ignored.
    assign write_accepted = wr_en && !full;
    assign read_accepted  = rd_en && !empty;

    always @(posedge clk) begin
        if (rst) begin
            write_ptr <= {ADDR_WIDTH{1'b0}};
            read_ptr  <= {ADDR_WIDTH{1'b0}};
            count     <= {COUNT_WIDTH{1'b0}};
            data_out  <= {DATA_WIDTH{1'b0}};
        end else begin
            if (write_accepted) begin
                memory[write_ptr] <= data_in;
                if (write_ptr == DEPTH - 1)
                    write_ptr <= {ADDR_WIDTH{1'b0}};
                else
                    write_ptr <= write_ptr + 1'b1;
            end

            if (read_accepted) begin
                data_out <= memory[read_ptr];
                if (read_ptr == DEPTH - 1)
                    read_ptr <= {ADDR_WIDTH{1'b0}};
                else
                    read_ptr <= read_ptr + 1'b1;
            end

            // Occupancy stays unchanged when a read and write are both accepted.
            case ({write_accepted, read_accepted})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule
