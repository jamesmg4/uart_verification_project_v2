module counter_tb;

    logic clk;
    logic rst_n;
    logic [2:0] count;

    // Device Under Test (DUT)
    counter dut (
        .clk(clk),
        .rst_n(rst_n),
        .count(count)
    );

    //--------------------------------------------------
    // Clock Generation
    //--------------------------------------------------

    initial begin
        clk = 0;

        forever #5 clk = ~clk;
    end

    //--------------------------------------------------
    // Reset and Test Stimulus
    //--------------------------------------------------

    initial begin

        rst_n = 0;

        #20;

        rst_n = 1;

        #100;

        $finish;

    end

    //--------------------------------------------------
    // Waveform Dump
    //--------------------------------------------------

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, counter_tb);
    end

endmodule