module uart_tx (
    input wire clk,          // 100MHz system clock
    input wire rst,          // Active high reset
    input wire start,        // Start transmission
    input wire [7:0] data,   // Data to transmit
    
    output reg done,         // Transmission complete
    output reg tx,           // UART TX line
    output reg tx_busy       // Transmission in progress
);

    // UART parameters for 115200 baud
    localparam BAUD_COUNT = 868; // 100MHz / 115200 ≈ 868
    
    // State machine
    reg [3:0] state, next_state;
    reg [9:0] baud_counter, next_baud_counter;
    reg [3:0] bit_index, next_bit_index;
    reg [7:0] data_reg, next_data_reg;
    reg next_done, next_tx, next_tx_busy;
    
    localparam IDLE = 4'd0,
               START_BIT = 4'd1,
               DATA_BITS = 4'd2,
               STOP_BIT = 4'd3,
               COMPLETE = 4'd4;

    // Sequential logic
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            baud_counter <= 10'd0;
            bit_index <= 4'd0;
            data_reg <= 8'd0;
            done <= 1'b0;
            tx <= 1'b1;
            tx_busy <= 1'b0;
        end else begin
            state <= next_state;
            baud_counter <= next_baud_counter;
            bit_index <= next_bit_index;
            data_reg <= next_data_reg;
            done <= next_done;
            tx <= next_tx;
            tx_busy <= next_tx_busy;
        end
    end

    // Combinational logic
    always @(*) begin
        next_state = state;
        next_baud_counter = baud_counter;
        next_bit_index = bit_index;
        next_data_reg = data_reg;
        next_done = 1'b0;
        next_tx = 1'b1;
        next_tx_busy = 1'b0;
        
        case (state)
            IDLE: begin
                next_tx = 1'b1;
                next_tx_busy = 1'b0;
                if (start) begin
                    next_state = START_BIT;
                    next_data_reg = data;
                    next_baud_counter = 10'd0;
                end
            end
            
            START_BIT: begin
                next_tx = 1'b0; // Start bit
                next_tx_busy = 1'b1;
                if (baud_counter == BAUD_COUNT - 1) begin
                    next_baud_counter = 10'd0;
                    next_state = DATA_BITS;
                    next_bit_index = 4'd0;
                end else begin
                    next_baud_counter = baud_counter + 1'b1;
                end
            end
            
            DATA_BITS: begin
                next_tx = data_reg[bit_index];
                next_tx_busy = 1'b1;
                if (baud_counter == BAUD_COUNT - 1) begin
                    next_baud_counter = 10'd0;
                    if (bit_index == 4'd7) begin
                        next_state = STOP_BIT;
                    end else begin
                        next_bit_index = bit_index + 1'b1;
                    end
                end else begin
                    next_baud_counter = baud_counter + 1'b1;
                end
            end
            
            STOP_BIT: begin
                next_tx = 1'b1; // Stop bit
                next_tx_busy = 1'b1;
                if (baud_counter == BAUD_COUNT - 1) begin
                    next_state = COMPLETE;
                end else begin
                    next_baud_counter = baud_counter + 1'b1;
                end
            end
            
            COMPLETE: begin
                next_done = 1'b1;
                next_tx_busy = 1'b0;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
