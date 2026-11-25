`timescale 1ns/1ps

module tb_sync_fifo;
    parameter integer DATA_WIDTH = 8;
    parameter integer FIFO_DEPTH = 8;
    localparam integer COUNT_WIDTH = $clog2(FIFO_DEPTH + 1);

    reg clk;
    reg rst;
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0] data_in;

    wire [DATA_WIDTH-1:0] data_out;
    wire full;
    wire empty;
    wire [COUNT_WIDTH-1:0] count;

    reg [DATA_WIDTH-1:0] model_memory [0:FIFO_DEPTH-1];
    integer model_write_ptr;
    integer model_read_ptr;
    integer model_count;
    integer errors;
    integer i;
    reg [1023:0] vcd_file;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) dut (
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

    always #5 clk = ~clk;

    initial begin
        if (!$value$plusargs("VCD=%s", vcd_file))
            vcd_file = "build/sync_fifo.vcd";
        $dumpfile(vcd_file);
        $dumpvars(0, tb_sync_fifo);
    end

    task reset_fifo;
        begin
            @(negedge clk);
            rst = 1'b1;
            wr_en = 1'b0;
            rd_en = 1'b0;
            model_write_ptr = 0;
            model_read_ptr = 0;
            model_count = 0;
            @(posedge clk);
            #1;
            if (count !== 0 || full !== 1'b0 || empty !== 1'b1) begin
                $display("FAIL: reset state is incorrect");
                errors = errors + 1;
            end
            @(negedge clk);
            rst = 1'b0;
        end
    endtask

    // Drives one cycle and checks accepted operations against a small software model.
    task apply_cycle;
        input write_request;
        input read_request;
        input [DATA_WIDTH-1:0] write_value;
        reg write_accepted;
        reg read_accepted;
        reg [DATA_WIDTH-1:0] expected_read_value;
        begin
            @(negedge clk);
            wr_en = write_request;
            rd_en = read_request;
            data_in = write_value;

            write_accepted = write_request && (model_count < FIFO_DEPTH);
            read_accepted  = read_request && (model_count > 0);

            if (read_accepted)
                expected_read_value = model_memory[model_read_ptr];

            if (write_accepted) begin
                model_memory[model_write_ptr] = write_value;
                if (model_write_ptr == FIFO_DEPTH - 1)
                    model_write_ptr = 0;
                else
                    model_write_ptr = model_write_ptr + 1;
            end

            if (read_accepted) begin
                if (model_read_ptr == FIFO_DEPTH - 1)
                    model_read_ptr = 0;
                else
                    model_read_ptr = model_read_ptr + 1;
            end

            if (write_accepted && !read_accepted)
                model_count = model_count + 1;
            else if (!write_accepted && read_accepted)
                model_count = model_count - 1;

            @(posedge clk);
            #1;

            if (read_accepted && data_out !== expected_read_value) begin
                $display("FAIL: read data mismatch; expected %h, received %h at time %0t",
                         expected_read_value, data_out, $time);
                errors = errors + 1;
            end

            if (count !== model_count) begin
                $display("FAIL: occupancy mismatch; expected %0d, received %0d at time %0t",
                         model_count, count, $time);
                errors = errors + 1;
            end

            if (full !== (model_count == FIFO_DEPTH)) begin
                $display("FAIL: full flag mismatch at time %0t", $time);
                errors = errors + 1;
            end

            if (empty !== (model_count == 0)) begin
                $display("FAIL: empty flag mismatch at time %0t", $time);
                errors = errors + 1;
            end

            wr_en = 1'b0;
            rd_en = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        wr_en = 1'b0;
        rd_en = 1'b0;
        data_in = {DATA_WIDTH{1'b0}};
        model_write_ptr = 0;
        model_read_ptr = 0;
        model_count = 0;
        errors = 0;

        reset_fifo;

        // A read while empty must be ignored.
        apply_cycle(1'b0, 1'b1, {DATA_WIDTH{1'b0}});

        // Fill the FIFO, then attempt one write beyond its capacity.
        for (i = 0; i < FIFO_DEPTH; i = i + 1)
            apply_cycle(1'b1, 1'b0, i + 1);
        apply_cycle(1'b1, 1'b0, {DATA_WIDTH{1'b1}});

        // Drain the FIFO and verify first-in, first-out ordering.
        for (i = 0; i < FIFO_DEPTH; i = i + 1)
            apply_cycle(1'b0, 1'b1, {DATA_WIDTH{1'b0}});
        apply_cycle(1'b0, 1'b1, {DATA_WIDTH{1'b0}});

        // A simultaneous read and write should preserve occupancy and ordering.
        apply_cycle(1'b1, 1'b0, 8'hA1);
        apply_cycle(1'b1, 1'b0, 8'hA2);
        apply_cycle(1'b1, 1'b1, 8'hB3);
        apply_cycle(1'b0, 1'b1, {DATA_WIDTH{1'b0}});
        apply_cycle(1'b0, 1'b1, {DATA_WIDTH{1'b0}});

        // Mixed traffic exercises pointer wrap-around and flag transitions.
        for (i = 0; i < 60; i = i + 1) begin
            if ((i % 5) == 0)
                apply_cycle(1'b1, 1'b1, i);
            else if ((i % 3) == 0)
                apply_cycle(1'b0, 1'b1, {DATA_WIDTH{1'b0}});
            else
                apply_cycle(1'b1, 1'b0, i);
        end

        while (model_count > 0)
            apply_cycle(1'b0, 1'b1, {DATA_WIDTH{1'b0}});

        if (errors == 0)
            $display("PASS: synchronous FIFO test completed (DATA_WIDTH=%0d, DEPTH=%0d)",
                     DATA_WIDTH, FIFO_DEPTH);
        else
            $fatal(1, "FAIL: synchronous FIFO test found %0d error(s)", errors);

        $finish;
    end
endmodule
