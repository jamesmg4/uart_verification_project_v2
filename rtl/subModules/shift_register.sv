module shift_register(
    
    input rst_n,
    input clk,

    input logic load,
    input logic shift,

    input logic [7:0] data_in,
    output logic data_out
);

logic [7:0] shift_reg;

assign data_out = shift_reg[0]; // outside the always_ff because this is essentially just represented as a wire


always_ff@(posedge clk or negedge rst_n) begin

    if(!rst_n)
        shift_reg <= 8'b0;
    else if(load)
        shift_reg <= data_in;
    else if(shift)
        shift_reg <= shift_reg >> 1;
    
end


endmodule