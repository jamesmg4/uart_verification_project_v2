module uart_rx #(
    parameter int BAUD_DIV = 10
)(
    input  logic clk,
    input  logic rst_n,

    input  logic rx,             // serial line coming from transmitter

    output logic [7:0] rx_data,  // received byte
    output logic rx_valid,       // pulse when a byte is received
    output logic rx_busy         // receiver currently receiving
);  



    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t; // created so that I can delare multple state variables cleanly

    state_t state, next_state;

    //shift register
    localparam int HALF_BAUD_DIV = BAUD_DIV / 2;
    localparam int BAUD_COUNTER_WIDTH = $clog2(BAUD_DIV);

    logic [2:0] bit_counter;
    logic [BAUD_COUNTER_WIDTH-1:0] baud_counter;

    logic baud_tick;

    assign baud_tick = (baud_counter == BAUD_COUNTER_WIDTH'(BAUD_DIV-1));
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
                if(baud_tick && bit_counter == 3'b111)
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
            rx_data <= 8'b0;
            bit_counter <= 3'b0;
            rx_valid <= 1'b0;
        end
        else begin
            rx_valid <= 1'b0; 
            case(state)
                IDLE: begin
                    bit_counter <= 3'b0;
                end
                DATA: begin
                    if(baud_tick) begin
                        rx_data[bit_counter] <= rx;
                        bit_counter <= bit_counter + 1'b1;
                    end
                end
                STOP: begin
                    if(baud_tick) begin
                        if(rx == 1'b1)
                            rx_valid <= 1'b1;
                    end
                end
                default: begin
                    //hold values
                end
            endcase
        end
    end

endmodule

/*
baud_counter decides WHEN to move
bit_counter decides HOW MANY data bits were sent
rx_data decides WHICH data bit is currently on tx
FSM decides WHAT phase we are in
*/