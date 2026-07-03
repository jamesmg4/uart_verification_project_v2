module uart_rx_tb;

    localparam int CLK_PERIOD = 10;
    localparam int BAUD_DIV   = 10;
    localparam int BIT_TIME   = CLK_PERIOD * BAUD_DIV;

    logic clk;
    logic rst_n;
    logic rx;

    logic [7:0] rx_data;
    logic       rx_valid;
    logic       rx_busy;

    uart_rx #(
        .BAUD_DIV(BAUD_DIV)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_busy(rx_busy)
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
    task automatic drive_uart_byte(input logic [7:0] data);
        int i;
        begin
            // idle before frame
            rx = 1'b1;
            #(BIT_TIME);

            // start bit
            rx = 1'b0;
            #(BIT_TIME);

            // data bits, LSB first
            for (i = 0; i < 8; i++) begin
                rx = data[i];
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
   task automatic send_and_check(input logic [7:0] data);
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
            for (i = 0; i < 8; i++) begin
                rx = data[i];
                #(BIT_TIME);
            end

            // stop bit
            rx = 1'b1;

            while (rx_valid != 1'b1 && timeout_count < 2000) begin
                @(posedge clk);
                timeout_count++;
            end

            if (timeout_count == 2000)
                $fatal(1, "Timeout waiting for rx_valid for byte %02h", data);

            assert (rx_data == data)
                else $error("Expected %02h, got %02h", data, rx_data);

            $display("PASS: RX byte %02h", data);

            #(BIT_TIME);
            repeat (2) @(posedge clk);
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

        send_and_check(8'hA5);
        send_and_check(8'h55);
        send_and_check(8'h00);
        send_and_check(8'hFF);

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