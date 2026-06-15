module uart_tx (

    input  logic clk,
    input  logic rst_n,

    input  logic tx_start,
    input  logic [7:0] tx_data,

    output logic tx,
    output logic tx_busy

);