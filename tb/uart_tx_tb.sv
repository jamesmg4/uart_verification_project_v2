module uart_tx_tb;

    localparam int CLK_PERIOD = 10;
    localparam int BAUD_DIV   = 10;
    localparam int BIT_TIME   = CLK_PERIOD * BAUD_DIV;

    logic clk;
    logic rst_n;
    logic tx_start;
    logic [7:0] tx_data;
    logic tx;
    logic tx_busy;

    uart_tx #(
        .BAUD_DIV(BAUD_DIV)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(tx),
        .tx_busy(tx_busy)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Check one transmitted byte
    task automatic send_and_check_byte(input logic [7:0] data);
        int i;

        begin
            // Start TX
            @(posedge clk);
            tx_data  = data;
            tx_start = 1'b1;

            @(posedge clk);
            tx_start = 1'b0;

            // Wait for falling edge of start bit
            @(negedge tx);

            // Check middle of start bit
            #(BIT_TIME/2);
            if (tx !== 1'b0)
                $error("START bit failed. Expected 0, got %b", tx);

            // Check data bits, LSB first
            for (i = 0; i < 8; i++) begin
                #(BIT_TIME);
                if (tx !== data[i])
                    $error("DATA bit %0d failed. Expected %b, got %b",
                           i, data[i], tx);
            end

            // Check stop bit
            #(BIT_TIME);
            if (tx !== 1'b1)
                $error("STOP bit failed. Expected 1, got %b", tx);

            // Wait until transmitter returns idle
            wait (tx_busy == 1'b0);

            $display("PASS: transmitted byte 0x%02h", data);
        end
    endtask

    // Main test
    initial begin
        byte rand_byte;

        rst_n    = 0;
        tx_start = 0;
        tx_data  = 8'h00;

        repeat (3) @(posedge clk);
        rst_n = 1;

        send_and_check_byte(8'h93);
        #100

        // repeat (1) begin
        //     rand_byte = $urandom_range(0, 255);
        //     send_and_check_byte(rand_byte);
        // end

        $display("All UART TX tests completed.");
        $finish;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            assert (!(tx_busy && dut.state == 2'b00))
                else $error("tx_busy high while state is IDLE");

            assert (!(dut.state == 2'b00 && tx !== 1'b1))
                else $error("tx not high during IDLE");

            assert (!(dut.state == 2'b01 && tx !== 1'b0))
                else $error("tx not low during START");

            assert (!(dut.state == 2'b11 && tx !== 1'b1))
                else $error("tx not high during STOP");

            assert (dut.bit_counter <= 3'd7)
                else $error("bit_counter exceeded 7");
        end
    end

    // Waveform dump
    initial begin
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, uart_tx_tb);
        $dumpvars(0, uart_tx_tb.dut);
    end

endmodule