module counter(
    input logic clk,
    input logic rst_n,

    output logic [2:0] count
);

always_ff@(posedge clk or negedge rst_n) begin

    if (!rst_n)
        count <= 3'b000;
    else
        count <= count + 1'b1;

end


endmodule