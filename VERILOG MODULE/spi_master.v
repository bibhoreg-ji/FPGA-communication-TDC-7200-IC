
module spi_master (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [7:0] addr,
    input wire [23:0] data_in,  // Max 24-bit for writes (only [7:0] used)
    input wire read_write,      // 1=write, 0=read
    input wire miso,
    
    output reg next_done,
    output reg [23:0] data_out, // Max 24-bit for reads
    output wire sclk,
    output reg mosi,
    output reg cs_n,
    output wire spi_busy        // New busy signal

);

// One-hot state encoding
parameter [5:0] IDLE        = 6'b000001,
                START_TRANS = 6'b000010,
                COMMAND_PHASE = 6'b000100,
                DATA_PHASE  = 6'b001000,
                END_TRANS   = 6'b010000,
                FINALIZE    = 6'b100000;

(* fsm_encoding = "one-hot" *) reg [5:0] state, next_state;
reg [4:0] clk_div_counter;
reg [4:0]  next_bit_counter, bit_counter;
reg [31:0] tx_shift_reg, next_tx_shift_reg;
reg [23:0] rx_shift_reg, next_rx_shift_reg;
reg sclk_int, sclk_posedge, sclk_negedge;
reg [23:0] next_data_out;
reg next_cs_n;
reg next_mosi;
wire [7:0] command_byte;
reg spi_active;
wire is_24bit_register;
wire [4:0] data_bits_to_transfer;

(* keep = "true" *) assign spi_busy = (state != IDLE);  // Busy when not in IDLE state

assign is_24bit_register = (addr == 8'h10) ||  // TIME1
                          (addr == 8'h11) ||  // CLOCK_COUNT1  
                          (addr == 8'h12) ||  // TIME2
                          (addr == 8'h13) ||  // CLOCK_COUNT2
                          (addr == 8'h14) ||  // TIME3
                          (addr == 8'h15) ||  // CLOCK_COUNT3
                          (addr == 8'h16) ||  // TIME4
                          (addr == 8'h17) ||  // CLOCK_COUNT4
                          (addr == 8'h18) ||  // TIME5
                          (addr == 8'h19) ||  // CLOCK_COUNT5
                          (addr == 8'h1A) ||  // TIME6
                          (addr == 8'h1B) ||  // CALIBRATION1
                          (addr == 8'h1C);    // CALIBRATION2
                          
assign data_bits_to_transfer = (read_write) ? 5'd8 : (is_24bit_register ? 5'd24 : 5'd8);
//(* keep = "true" *) assign spi_active = (state != IDLE);
assign sclk = sclk_int;
assign command_byte = {1'b0, read_write, addr[5:0]};

// Clock generator;
always @(posedge clk or posedge rst) begin
    if (rst)
        spi_active <= 1'b0;
    else
        spi_active <= (state != IDLE);
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        clk_div_counter <= 0;
        sclk_int <= 0;
        sclk_posedge <= 0;
        sclk_negedge <= 0;
    end else begin
        sclk_posedge <= 0;
        sclk_negedge <= 0;
        if (spi_active && clk_div_counter == 5'd19) begin
            clk_div_counter <= 0;
            sclk_int <= ~sclk_int;
            if (~sclk_int)
                sclk_posedge <= 1;
            else
                sclk_negedge <= 1;
        end else if (spi_active) begin
            clk_div_counter <= clk_div_counter + 1;
        end else begin
            clk_div_counter <= 0;
            sclk_int <= 0;
        end
    end
end

// State and control registers
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        bit_counter <= 5'd0;
        tx_shift_reg <= 32'd0;
        rx_shift_reg <= 24'd0;
        data_out <= 24'd0;
        cs_n <= 1'b1;
        mosi <= 1'b0;
//        done <= 1'b0;
    end else begin
        state <= next_state;
        bit_counter <= next_bit_counter;
        tx_shift_reg <= next_tx_shift_reg;
        rx_shift_reg <= next_rx_shift_reg;
        data_out <= next_data_out;
        cs_n <= next_cs_n;
        mosi <= next_mosi;
//        done <= next_done;
    end
end

// Next state and output logic
always @(*) begin
    // Default values
    next_state = state;
    next_cs_n = 1;
    next_done = 0;
    next_mosi = 0;
    next_data_out = data_out;
    next_tx_shift_reg = tx_shift_reg;
    next_rx_shift_reg = rx_shift_reg;
    next_bit_counter = bit_counter;

    case (state)
        IDLE: begin
            next_cs_n = 1;
            next_bit_counter = 0;
            if (start) begin
                next_state = START_TRANS;
                next_tx_shift_reg = (read_write) ? {command_byte, data_in[7:0], 16'b0} : {command_byte, 24'b0};
                next_rx_shift_reg = 24'd0;
            end
        end

        START_TRANS: begin
            next_cs_n = 0;
            next_state = COMMAND_PHASE;
        end

        COMMAND_PHASE: begin
            next_cs_n = 0;
            next_mosi = tx_shift_reg[31];
            if (sclk_negedge) begin
                next_tx_shift_reg = {tx_shift_reg[30:0], 1'b0};
            end
            if (sclk_posedge) begin
                if (bit_counter == 5'd7) begin
                    next_state = DATA_PHASE;
                    next_bit_counter = 5'd0;
                end
                
                else next_bit_counter = bit_counter + 1;
            end
        end

        DATA_PHASE: begin
            next_cs_n = 0;
            next_mosi = tx_shift_reg[31];
            if (sclk_negedge) begin
                next_tx_shift_reg = {tx_shift_reg[30:0], 1'b0};
            end
            if (sclk_posedge) begin
                next_bit_counter = bit_counter + 1;
                if (!read_write) begin
                    if (is_24bit_register)
                        next_rx_shift_reg = {rx_shift_reg[22:0], miso};
                    else
                        next_rx_shift_reg = {16'd0, rx_shift_reg[6:0], miso};
                end
                if (bit_counter + 1 == data_bits_to_transfer) begin
                    next_state = END_TRANS;
                end
            end
        end

        END_TRANS: begin
            next_cs_n = 1;
            if (sclk_negedge) begin
                next_data_out = rx_shift_reg;
                next_mosi = 0;
                next_state = FINALIZE;
                next_done = 0;
            end
        end

        FINALIZE: begin
            next_done = 1;
            next_mosi = 0;
            next_cs_n = 1;
            next_bit_counter = 0;
            next_state = IDLE;
        end
        
        6'd0: begin
            next_cs_n = 1'b0;
        end

    endcase
end

endmodule


