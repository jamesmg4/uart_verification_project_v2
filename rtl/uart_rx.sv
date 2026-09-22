module uart_rx #(
    parameter int BAUD_RATE = 10,
    parameter int CLK_SPEED = 100,
    parameter DATA_BITS = 8,
    parameter bit PARITY_ENABLE = 1'b0,
    parameter bit PARITY_ODD = 1'b0
)(
    input  logic clk,
    input  logic rst_n,

    input  logic rx,             // serial line coming from transmitter

    output logic [DATA_BITS-1:0] rx_data,  // received byte
    output logic rx_valid,       // pulse when a byte is received
    output logic rx_busy,        // receiver currently receiving
    output logic parity_error,   // pulse when the received parity bit is wrong
    output logic framing_error   // pulse when the stop bit is not high
);  



    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        PARITY,
        STOP
    } state_t; // created so that I can delare multple state variables cleanly

    state_t state, next_state;

    localparam int CLKS_PER_BIT = CLK_SPEED/BAUD_RATE;
    localparam int BAUD_COUNTER_WIDTH = (CLKS_PER_BIT == 1) ? 1 : $clog2(CLKS_PER_BIT);
    localparam int BIT_COUNTER_WIDTH = (DATA_BITS == 1) ? 1 : $clog2(DATA_BITS);

    //shift register
    localparam int HALF_BAUD_DIV = CLKS_PER_BIT / 2;

    logic [BIT_COUNTER_WIDTH-1:0] bit_counter;
    logic [BAUD_COUNTER_WIDTH-1:0] baud_counter;

    logic baud_tick;
    logic parity_error_latched;

    assign baud_tick = (baud_counter == BAUD_COUNTER_WIDTH'(CLKS_PER_BIT-1));
    assign rx_busy = (state != IDLE);

    // state register
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    //next state
    always_comb begin
        next_state = state;
        case(state)
            IDLE: begin
                if(rx == 0)
                    next_state = START;
            end
            START: begin
                if(baud_counter == BAUD_COUNTER_WIDTH'(HALF_BAUD_DIV-1)) begin
                    if(rx == 1'b0)
                        next_state = DATA;
                    else
                        next_state = IDLE;
                end
                    
            end
            DATA: begin
                if(baud_tick && bit_counter == BIT_COUNTER_WIDTH'(DATA_BITS-1))
                    next_state = PARITY_ENABLE ? PARITY : STOP;
            end
            PARITY: begin
                if(baud_tick)
                    next_state = STOP;
            end
            STOP: begin
                if(baud_tick)
                    next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase 
    end


    //Baud counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            baud_counter <= '0;
        else if (state == IDLE)
            baud_counter <= '0;
        else if (state == START && baud_counter == BAUD_COUNTER_WIDTH'(HALF_BAUD_DIV-1))
            baud_counter <= '0;
        else if (baud_tick)
            baud_counter <= '0;
        else
            baud_counter <= baud_counter + 1'b1;
    end

    //shift register and bit counter
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            rx_data <= '0;
            bit_counter <= '0;
            rx_valid <= 1'b0;
            parity_error <= 1'b0;
            framing_error <= 1'b0;
            parity_error_latched <= 1'b0;
        end
        else begin
            rx_valid <= 1'b0; 
            parity_error <= 1'b0;
            framing_error <= 1'b0;
            case(state)
                IDLE: begin
                    bit_counter <= '0;
                    parity_error_latched <= 1'b0;
                end
                PARITY: begin
                    if (baud_tick)
                        parity_error_latched <= (rx !== (PARITY_ODD ? ~^rx_data : ^rx_data));
                end
                DATA: begin
                    if(baud_tick) begin
                        rx_data[bit_counter] <= rx;
                        if (bit_counter < BIT_COUNTER_WIDTH'(DATA_BITS-1))
                            bit_counter <= bit_counter + 1'b1;
                    end
                end
                STOP: begin
                    if(baud_tick) begin
                        if(rx == 1'b1)
                            rx_valid <= 1'b1;
                        else
                            framing_error <= 1'b1;
                        parity_error <= PARITY_ENABLE && parity_error_latched;
                    end
                end
                default: begin
                    //hold values
                end
            endcase
        end
    end

`ifndef SYNTHESIS
    logic rx_valid_previous;

    // rx_valid is an event pulse, so it may be sampled high for only one
    // rising clock edge per completed frame.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_valid_previous <= 1'b0;
        end
        else begin
            assert (!((rx_valid === 1'b1) && (rx_valid_previous === 1'b1)))
                else $error("uart_rx: rx_valid remained high for more than one clock cycle");
            assert ($unsigned(baud_counter) < CLKS_PER_BIT)
                else $error("uart_rx: baud_counter exceeded its valid range");
            assert ($unsigned(bit_counter) < DATA_BITS)
                else $error("uart_rx: bit_counter exceeded its valid range");
            rx_valid_previous <= rx_valid;
        end
    end
`endif

endmodule

/*
baud_counter decides WHEN to move
bit_counter decides HOW MANY data bits were sent
rx_data decides WHICH data bit is currently on tx
FSM decides WHAT phase we are in
*/
