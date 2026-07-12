module uart_tx #(
    parameter int BAUD_RATE = 10,
    parameter int CLK_SPEED = 100,
    parameter DATA_BITS = 8,
    parameter bit PARITY_ENABLE = 1'b1,
    parameter bit PARITY_ODD = 1'b1
)(
    input  logic clk,   
    input  logic rst_n,

    input  logic tx_start,
    input  logic [DATA_BITS-1:0] tx_data,

    output logic tx,
    output logic tx_busy
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
    localparam int BAUD_COUNTER_WIDTH = ($clog2(CLKS_PER_BIT) == 1) ? 1 : $clog2(CLKS_PER_BIT);
    localparam int BIT_COUNTER_WIDTH = ($clog2(DATA_BITS) == 1) ? 1 : $clog2(DATA_BITS);

    //shift register
    logic [DATA_BITS:0] shift_reg;
    logic [BIT_COUNTER_WIDTH-1:0] bit_counter;
    logic [BAUD_COUNTER_WIDTH-1:0] baud_counter;

    logic baud_tick;
    bit parity_bit;

    assign baud_tick = (baud_counter == CLKS_PER_BIT-1);
    assign tx_busy = (state != IDLE);
    

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
                if(tx_start)
                    next_state = START;
            end
            START: begin
                if(baud_tick)
                    next_state = DATA;
            end
            DATA: begin
                if(baud_tick && bit_counter == DATA_BITS-1)
                    next_state = (PARITY_ENABLE == 1) ? PARITY : STOP;
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
        else if (baud_tick)
            baud_counter <= '0;
        else
            baud_counter <= baud_counter + 1'b1;
    end

    //shift register and bit counter
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            shift_reg <= 8'b0;
            bit_counter <= 3'b0;
        end
        else begin
            case(state)
                IDLE: begin
                    bit_counter <= 3'b0;
                
                    if(tx_start) begin
                        shift_reg <= tx_data;
                        if(PARITY_ODD) begin
                            parity_bit <= ~^tx_data;
                        end
                        else begin
                            parity_bit <= ^tx_data;
                        end
                    end
                end
                DATA: begin
                    if(baud_tick) begin
                        shift_reg <= shift_reg >> 1;
                        bit_counter <= bit_counter + 1'b1;
                    end
                end
                default: begin
                    //hold values
                end
            endcase
        end
    end

    always_comb begin
        case(state)
            IDLE:
                tx = 1'b1;
            START:
                tx = 1'b0;
            DATA:
                tx = shift_reg[0];
            PARITY:
                tx = parity_bit;
            STOP:
                tx = 1'b1;
            default: begin
                tx = 1'b1;
            end
        endcase
    end

endmodule

/*
baud_counter decides WHEN to move
bit_counter decides HOW MANY data bits were sent
shift_reg decides WHICH data bit is currently on tx
FSM decides WHAT phase we are in
*/
