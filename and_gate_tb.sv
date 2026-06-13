module and_gate_tb;

logic a, b;
logic y;

and_gate dut (
    .a(a),
    .b(b),
    .y(y)
);

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, and_gate_tb);

    a = 0; b = 0; #10;
    a = 0; b = 1; #10;
    a = 1; b = 0; #10;
    a = 1; b = 1; #10;

    $finish;
end

endmodule