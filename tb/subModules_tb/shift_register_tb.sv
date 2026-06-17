module shift_register_tb;

    logic rst_n,
    logic clk,

    logic load,
    logic shift,

    logic [7:0] data_in,
    logic data_out

    // Device Under Test (DUT)
    shift_register dut (
        .clk(clk),
        .rst_n(rst_n),
        .load(load),
        .shift(shift),
        .data_in(data_in),
        .data_out(data_out)
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
        load = 0;
        shift = 0;
        data_in = 8'b0000_0000;

        #20;

        rst_n = 1;
        //load byte
        data_in = 10011001;
        load = 1;
        #10;
        load=0;


        shift = 1;
        #80
        shift = 0;
        #25;

        $finish;

    end

    //--------------------------------------------------
    // Waveform Dump
    //--------------------------------------------------

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, shift_register_tb);
    end

endmodule