module uart_loopback_tb;

    // Keep these settings aligned with both DUT instances below.
    localparam int CLK_PERIOD = 10;
    localparam int CLK_SPEED  = 100;
    localparam int BAUD_RATE  = 10;
    localparam int DATA_BITS  = 8;

    localparam int CLKS_PER_BIT = CLK_SPEED / BAUD_RATE;
    localparam int BIT_TIME     = CLK_PERIOD * CLKS_PER_BIT;

    logic clk;
    logic rst_n;

    logic serial_line;

    logic tx_start;
    logic [DATA_BITS-1:0] tx_data;
    logic tx_busy;

    logic [DATA_BITS-1:0] rx_data;
    logic rx_valid;
    logic rx_busy;

    uart_tx #(
        .BAUD_RATE(BAUD_RATE),
        .CLK_SPEED(CLK_SPEED),
        .DATA_BITS(DATA_BITS)
    ) tx_dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(serial_line),
        .tx_busy(tx_busy)
    );

    uart_rx #(
        .BAUD_RATE(BAUD_RATE),
        .CLK_SPEED(CLK_SPEED),
        .DATA_BITS(DATA_BITS)
    ) rx_dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(serial_line),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_busy(rx_busy)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    task automatic wait_for_idle;
        begin
            wait (tx_busy == 1'b0);
            wait (rx_busy == 1'b0);
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic pulse_tx_start(input logic [DATA_BITS-1:0] data);
        begin
            @(negedge clk);
            tx_data  = data;
            tx_start = 1'b1;

            @(negedge clk);
            tx_start = 1'b0;
        end
    endtask

    task automatic send_and_expect(input logic [DATA_BITS-1:0] data);
        begin
            $display("Starting byte %0h at time %0t", data, $time);
            wait_for_idle();
            pulse_tx_start(data);

            wait (rx_valid == 1'b1);

            assert (rx_data == data)
                else $error("Expected %0h, got %0h", data, rx_data);

            $display("PASS: TX->RX byte %0h", data);
        end
    endtask

    task automatic test_basic_loopback;
        begin
            $display("\n--- test_basic_loopback ---");
            send_and_expect(8'h00);
            send_and_expect(8'hFF);
            send_and_expect(8'h55);
            send_and_expect(8'hAA);
            send_and_expect(8'h92);
        end
    endtask

    task automatic test_random_loopback;
        logic [DATA_BITS-1:0] rand_byte;
        begin
            $display("\n--- test_random_loopback ---");
            repeat (100) begin
                rand_byte = $urandom;
                send_and_expect(rand_byte);
            end
        end
    endtask

    task automatic test_tx_start_while_busy_is_ignored;
        logic [DATA_BITS-1:0] first_byte;
        logic [DATA_BITS-1:0] ignored_byte;
        begin
            $display("\n--- test_tx_start_while_busy_is_ignored ---");
            first_byte   = 8'h3C;
            ignored_byte = 8'hA7;

            wait_for_idle();
            pulse_tx_start(first_byte);
            wait (tx_busy == 1'b1);

            // Request another transfer while the first one is active.
            pulse_tx_start(ignored_byte);

            wait (rx_valid == 1'b1);
            assert (rx_data == first_byte)
                else $error("Busy test: expected first byte %0h, got %0h", first_byte, rx_data);

            // Give enough time for an incorrectly accepted second frame to appear.
            repeat (CLKS_PER_BIT * (DATA_BITS + 4)) @(posedge clk);
            assert (tx_busy == 1'b0)
                else $error("Busy test: TX did not return to idle");
            assert (rx_valid == 1'b0)
                else $error("Busy test: TX accepted tx_start while tx_busy was high");

            $display("PASS: tx_start while tx_busy is ignored");
        end
    endtask

    task automatic test_tx_data_is_captured_at_start;
        logic [DATA_BITS-1:0] expected_byte;
        begin
            $display("\n--- test_tx_data_is_captured_at_start ---");
            expected_byte = 8'h92;

            wait_for_idle();
            pulse_tx_start(expected_byte);
            wait (tx_busy == 1'b1);

            // Change the input bus during the active frame without another start request.
            @(negedge clk);
            tx_data = 8'h0F;

            wait (rx_valid == 1'b1);
            assert (rx_data == expected_byte)
                else $error("Data capture test: expected %0h, got %0h", expected_byte, rx_data);

            $display("PASS: tx_data is captured when tx_start is accepted");
        end
    endtask

    task automatic test_reset_during_transfer;
        begin
            $display("\n--- test_reset_during_transfer ---");
            wait_for_idle();
            pulse_tx_start(8'hC3);
            wait (tx_busy == 1'b1);
            repeat (CLKS_PER_BIT * 3) @(posedge clk);

            @(negedge clk);
            rst_n = 1'b0;
            @(posedge clk);

            assert (tx_busy == 1'b0)
                else $error("Reset test: tx_busy did not clear");
            assert (rx_busy == 1'b0)
                else $error("Reset test: rx_busy did not clear");
            assert (serial_line == 1'b1)
                else $error("Reset test: TX line did not return to idle high");

            @(negedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);

            // Confirm both blocks work after reset recovery.
            send_and_expect(8'h5A);
            $display("PASS: reset aborts an active transfer and recovers cleanly");
        end
    endtask

    initial begin
        rst_n    = 0;
        tx_start = 0;
        tx_data  = 8'h00;

        repeat (3) @(posedge clk);
        rst_n = 1;

        repeat (2) @(posedge clk);
        
        // Change CLK_SPEED, BAUD_RATE, or DATA_BITS above to rerun this same
        // end-to-end suite with a different UART configuration.
        test_basic_loopback();
        test_random_loopback();
        test_tx_start_while_busy_is_ignored();
        test_tx_data_is_captured_at_start();
        test_reset_during_transfer();

        $display("\nAll UART loopback tests complete.");
        $finish;
    end

    initial begin
        #100000000;
        $fatal(1, "Global timeout");
    end
    
    initial begin
        $dumpfile("uart_loopback.vcd");
        $dumpvars(0, uart_loopback_tb);
    end

endmodule