`timescale 1ns/1ps
module uart_rx_tb;

    // Keep these settings aligned with the DUT parameters below.
    localparam int CLK_PERIOD = 10;
    localparam int CLK_SPEED  = 100000000;
    localparam int BAUD_RATE  = 10000000;
    localparam int DATA_BITS  = 8;
    localparam bit PARITY_ENABLE = 1'b1;
    localparam bit PARITY_ODD = 1'b1;

    localparam int CLKS_PER_BIT = CLK_SPEED / BAUD_RATE;
    localparam int BIT_TIME     = CLK_PERIOD * CLKS_PER_BIT;

    logic clk;
    logic rst_n;
    logic rx;

    logic [DATA_BITS-1:0] rx_data;
    logic       rx_valid;
    logic       rx_busy;
    logic       parity_error;
    logic       framing_error;

    uart_rx #(
        .BAUD_RATE(BAUD_RATE),
        .CLK_SPEED(CLK_SPEED),
        .DATA_BITS(DATA_BITS),
        .PARITY_ENABLE(PARITY_ENABLE),
        .PARITY_ODD(PARITY_ODD)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_busy(rx_busy),
        .parity_error(parity_error),
        .framing_error(framing_error)
    );

    //--------------------------------------------------
    // Clock generation
    //--------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //--------------------------------------------------
    // Drive a UART frame into RX
    //--------------------------------------------------
    task automatic drive_uart_byte(input logic [DATA_BITS-1:0] data);
        int i;
        begin
            // idle before frame
            rx = 1'b1;
            #(BIT_TIME);

            // start bit
            rx = 1'b0;
            #(BIT_TIME);

            // data bits, LSB first
            for (i = 0; i < DATA_BITS; i++) begin
                rx = data[i];
                #(BIT_TIME);
            end

            if (PARITY_ENABLE) begin
                rx = PARITY_ODD ? ~^data : ^data;
                #(BIT_TIME);
            end

            // stop bit
            rx = 1'b1;
            #(BIT_TIME);
        end
    endtask

    //--------------------------------------------------
    // Send one byte and check received result
    //--------------------------------------------------
    task automatic send_and_check(input logic [DATA_BITS-1:0] data);
        int i;
        int timeout_count;

        begin
            timeout_count = 0;

            // idle before frame
            rx = 1'b1;
            #(BIT_TIME);

            // start bit
            rx = 1'b0;
            #(BIT_TIME);

            // data bits, LSB first
            for (i = 0; i < DATA_BITS; i++) begin
                rx = data[i];
                #(BIT_TIME);
            end

            if (PARITY_ENABLE) begin
                rx = PARITY_ODD ? ~^data : ^data;
                #(BIT_TIME);
            end

            // stop bit
            rx = 1'b1;

            while (rx_valid != 1'b1 && timeout_count < 2000) begin
                @(posedge clk);
                timeout_count++;
            end

            if (timeout_count == 2000)
                $fatal(1, "Timeout waiting for rx_valid for byte %0h", data);

            assert (rx_data == data)
                else $error("Expected %0h, got %0h", data, rx_data);
            assert (parity_error == 1'b0)
                else $error("Unexpected parity error for byte %0h", data);
            assert (framing_error == 1'b0)
                else $error("Unexpected framing error for byte %0h", data);

            $display("PASS: RX byte %0h", data);

            #(BIT_TIME);
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic test_bad_stop_bit(input logic [DATA_BITS-1:0] data);
        int i;
        begin
            rx = 1'b1;
            #(BIT_TIME);
            rx = 1'b0;
            #(BIT_TIME);
            for (i = 0; i < DATA_BITS; i++) begin
                rx = data[i];
                #(BIT_TIME);
            end

            if (PARITY_ENABLE) begin
                rx = PARITY_ODD ? ~^data : ^data;
                #(BIT_TIME);
            end

            // A valid UART stop bit must remain high for the full bit period.
            rx = 1'b0;
            wait (framing_error == 1'b1);
            assert (rx_valid == 1'b0)
                else $error("RX marked a frame with a bad stop bit as valid");
            assert (rx_data == data)
                else $error("Bad-stop test data mismatch: expected %0h, got %0h", data, rx_data);
            $display("PASS: bad stop bit detected for byte %0h", data);

            rx = 1'b1;
            #(BIT_TIME);
        end
    endtask

    task automatic test_bad_parity(input logic [DATA_BITS-1:0] data);
        int i;
        begin
            rx = 1'b1;
            #(BIT_TIME);
            rx = 1'b0;
            #(BIT_TIME);
            for (i = 0; i < DATA_BITS; i++) begin
                rx = data[i];
                #(BIT_TIME);
            end

            // Deliberately send the inverse of the configured parity bit.
            rx = ~(PARITY_ODD ? ~^data : ^data);
            #(BIT_TIME);
            rx = 1'b1;

            wait (rx_valid == 1'b1);
            assert (parity_error == 1'b1)
                else $error("Bad parity was not detected for byte %0h", data);
            $display("PASS: bad parity detected for byte %0h", data);
            #(BIT_TIME);
        end
    endtask

    //--------------------------------------------------
    // Reset during an active frame
    //--------------------------------------------------
    task automatic test_reset_during_receive;
        begin
            // Start a frame and hold RX low for the start bit.
            @(negedge clk);
            rx = 1'b0;

            // Wait long enough for the receiver to leave IDLE and begin reception.
            #(2 * BIT_TIME);

            // Assert reset away from the DUT sampling edge.
            @(negedge clk);
            rst_n = 1'b0;

            // Reset should immediately cancel the partially received frame.
            #1;
            assert (rx_busy == 1'b0)
                else $error("RESET test failed: rx_busy did not return low");
            assert (rx_valid == 1'b0)
                else $error("RESET test failed: rx_valid remained high");
            assert (framing_error == 1'b0)
                else $error("RESET test failed: framing_error remained high");

            // Release reset on a safe edge and restore the idle line.
            @(negedge clk);
            rst_n = 1'b1;
            rx    = 1'b1;

            repeat (2) @(posedge clk);

            if (rx_busy == 1'b0 && rx_valid == 1'b0)
                $display("PASS: reset during reception returned RX to idle");
        end
    endtask

    //--------------------------------------------------
    // Main test
    //--------------------------------------------------
    initial begin
        rst_n = 1'b0;
        rx    = 1'b1;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        repeat (2) @(posedge clk);
        
        // Reset must abort a partially received UART frame.
        test_reset_during_receive();

        // For a different configuration, change DATA_BITS, BAUD_RATE, or CLK_SPEED
        // above; these same tests will adapt to the configured frame width and timing.
        send_and_check(8'hA5);
        send_and_check(8'h55);
        send_and_check(8'h00);
        send_and_check(8'hFF);
        test_bad_parity(8'h3C);
        test_bad_stop_bit(8'h69);

        $display("UART RX tests complete.");
        $finish;
    end

    //--------------------------------------------------
    // Waveform dump
    //--------------------------------------------------
    initial begin
        $dumpfile("uart_rx.vcd");
        $dumpvars(0, uart_rx_tb);
    end

endmodule
