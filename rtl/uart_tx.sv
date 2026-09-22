module uart_tx #(
    parameter int BAUD_RATE = 10,
    parameter int CLK_SPEED = 100,
    parameter DATA_BITS = 8,
    parameter bit PARITY_ENABLE = 1'b0,
    parameter bit PARITY_ODD = 1'b0
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
    localparam int BAUD_COUNTER_WIDTH = (CLKS_PER_BIT == 1) ? 1 : $clog2(CLKS_PER_BIT);
    localparam int BIT_COUNTER_WIDTH = (DATA_BITS == 1) ? 1 : $clog2(DATA_BITS);

    //shift register
    logic [DATA_BITS-1:0] shift_reg;
    logic [BIT_COUNTER_WIDTH-1:0] bit_counter;
    logic [BAUD_COUNTER_WIDTH-1:0] baud_counter;

    logic baud_tick;
    logic parity_bit;

    assign baud_tick = (baud_counter == BAUD_COUNTER_WIDTH'(CLKS_PER_BIT-1));
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
        else if (baud_tick)
            baud_counter <= '0;
        else
            baud_counter <= baud_counter + 1'b1;
    end

    //shift register and bit counter
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            shift_reg <= '0;
            bit_counter <= '0;
            parity_bit <= '0;
        end
        else begin
            case(state)
                IDLE: begin
                    bit_counter <= '0;
                
                    if(tx_start) begin
                        shift_reg <= tx_data;
                        // Reduction XOR produces even parity. Invert it for odd parity.
                        parity_bit <= PARITY_ODD ? ~^tx_data : ^tx_data;
                    end
                end
                DATA: begin
                    if(baud_tick) begin
                        shift_reg <= shift_reg >> 1;
                        if (bit_counter < BIT_COUNTER_WIDTH'(DATA_BITS-1))
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

`ifndef SYNTHESIS
    // The transmitter has no request queue. A start request made during an
    // active frame is ignored, so flag the interface misuse without stopping
    // the simulation.
    always @(posedge clk) begin
        if (rst_n) begin
            if (tx_busy && tx_start)
                $warning("uart_tx: tx_start asserted while tx_busy; request ignored");

            if (state === IDLE) begin
                assert (tx === 1'b1)
                    else $error("uart_tx: tx must be high while idle");
            end

            assert ($unsigned(baud_counter) < CLKS_PER_BIT)
                else $error("uart_tx: baud_counter exceeded its valid range");
            assert ($unsigned(bit_counter) < DATA_BITS)
                else $error("uart_tx: bit_counter exceeded its valid range");
        end
    end
`endif

endmodule

/*
baud_counter decides WHEN to move
bit_counter decides HOW MANY data bits were sent
shift_reg decides WHICH data bit is currently on tx
FSM decides WHAT phase we are in
*/
