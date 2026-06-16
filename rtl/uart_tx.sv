module uart_tx(
    input  logic clk,
    input  logic rst_n,

    input  logic tx_start,
    input  logic [7:0] tx_data,

    output logic tx,
    output logic tx_busy
);

endmodule

typedef enum logic [1:0] {
    IDLE,
    START,
    DATA,
    STOP
} state_t;

state_t state;
state_t next_state;

    //local signals
    state_t state;
    logic [7:0] shift_reg;
    logic [2:0] bit_counter;
    logic [BAUD_COUNTER_WIDTH-1:0] baud_counter;
