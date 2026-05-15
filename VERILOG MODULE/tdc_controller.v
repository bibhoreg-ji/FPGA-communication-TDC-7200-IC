

module tdc_controller (
    input wire clk,              // 100MHz system clock
    input wire rst,              // Active high reset
    input wire tdc_intb,         // TDC interrupt (active low)
    input wire tdc_trigg,        // TDC trigger output
    input wire spi_done,         // SPI transaction complete
    input wire spi_busy,         // SPI transaction in progress
    input wire [23:0] spi_data_out, // Data from SPI read
    input wire uart_done,        // UART transmission complete
    input wire uart_busy,        // UART transaction in progress
    
    output reg tdc_en,           // TDC enable pin
    output reg tdc_start,        // TDC start signal
    output reg tdc_stop,         // TDC stop signal
    output reg spi_start,        // Start SPI transaction
    output reg read_write,
    output reg [7:0] spi_addr,   // SPI address
    output reg [7:0] spi_data_in, // SPI data to write
    output reg uart_start,       // Start UART transmission
    output reg [7:0] uart_data,   // UART data to send
    output wire [3:0] led_state
);

    

    
    // Parameters
    parameter TEST_DELAY_NS = 100; // 120ns test delay (12 clock cycles)
    localparam DELAY_CYCLES = TEST_DELAY_NS / 10; // Convert to clock cycles
    
    // State machine
    reg [3:0] state, next_state;
    reg [31:0] counter, next_counter;
    reg [3:0] config_step, next_config_step;
    reg [7:0] uart_byte_count, next_uart_byte_count;
    reg [23:0] time1_reg, cal1_reg, cal2_reg;
    reg [23:0] next_time1_reg, next_cal1_reg, next_cal2_reg;
    
    // Control signals
    reg next_tdc_en, next_tdc_start, next_tdc_stop;
    reg next_spi_start, next_uart_start;
    reg [7:0] next_spi_addr, next_uart_data;
    reg [7:0] next_spi_data_in;
    reg next_read_write;
    
    assign led_state = state;
             
    // States
    localparam RESET_STATE = 4'd0,  
               WAIT_READY = 4'd1,
               CONFIG_TDC = 4'd2,
               START_MEAS = 4'd3,
               WAIT_TRIGG = 4'd4,
               SEND_START = 4'd5,
               WAIT_DELAY = 4'd6,
               SEND_STOP = 4'd7,
               WAIT_INTB = 4'd8,
               READ_RESULTS = 4'd9,
               SEND_UART = 4'd10,
               DONE_STATE = 4'd11;
    
    // Sequential logic
    always @(posedge clk) begin
        if (rst) begin
            state <= RESET_STATE;
            counter <= 32'd0;
            config_step <= 4'd0;
            uart_byte_count <= 8'd0;
            time1_reg <= 24'd0;
            cal1_reg <= 24'd0;
            cal2_reg <= 24'd0;
            tdc_en <= 1'b0;
            tdc_start <= 1'b0;
            tdc_stop <= 1'b0;
            spi_start <= 1'b0;
            spi_addr <= 8'd0;
            spi_data_in <= 8'd0;
            uart_start <= 1'b0;
            uart_data <= 8'd0;
            read_write <= 1'b0;
            
        end else begin
            state <= next_state;
            counter <= next_counter;
            config_step <= next_config_step;
            uart_byte_count <= next_uart_byte_count;
            time1_reg <= next_time1_reg;
            cal1_reg <= next_cal1_reg;
            cal2_reg <= next_cal2_reg;
            tdc_en <= next_tdc_en;
            tdc_start <= next_tdc_start;
            tdc_stop <= next_tdc_stop;
            spi_start <= next_spi_start;
            spi_addr <= next_spi_addr;
            spi_data_in <= next_spi_data_in;
            uart_start <= next_uart_start;
            uart_data <= next_uart_data;
            read_write <= next_read_write;
        end
    end

    // Combinational logic
    always @(*) begin
        // Default values
        next_state = state;
        next_counter = counter;
        next_config_step = config_step;
        next_uart_byte_count = uart_byte_count;
        next_time1_reg = time1_reg;
        next_cal1_reg = cal1_reg;
        next_cal2_reg = cal2_reg;
        next_tdc_en = tdc_en;
        next_tdc_start = 1'b0;
        next_tdc_stop = 1'b0;
        next_spi_start = 1'b0;
        next_spi_addr = spi_addr;
        next_spi_data_in = spi_data_in;
        next_uart_start = 1'b0;
        next_uart_data = uart_data;
        next_read_write = read_write;
        
        case (state)
            RESET_STATE: begin
                
                next_counter = 32'd0;
                next_state = WAIT_READY;
            end
            
            WAIT_READY: begin
                // Wait 30,000 cycles (300us at 100MHz)
                next_tdc_en = 1'b1; // Enable TDC
                if (counter < 32'd30000) begin
                    next_counter = counter + 1'b1;
                end else begin
                    next_state = CONFIG_TDC;
                    next_counter = 32'd0;
                    next_config_step = 4'd0;
                end
            end
            
            
            CONFIG_TDC: begin
                if (spi_done) begin
                    next_state = START_MEAS;
                end else if (!spi_busy) begin
                    next_spi_start = 1'b1;
                    next_spi_addr = 8'h01;  // CONFIG2 Register
                    next_spi_data_in = 8'h40; // Single STOP, 10 cal periods
                    next_read_write = 1'b1;
                end
                // If spi_busy is true, just wait
            end
            
            START_MEAS: begin
                if (spi_done) begin
                    next_state = WAIT_TRIGG;
                end else if (!spi_busy) begin
                    next_spi_start = 1'b1;
                    next_spi_addr = 8'h00;
                    next_spi_data_in = 8'h01; // Set START_MEAS bit
                    next_read_write = 1'b1;
                end
                // If spi_busy is true, just wait
            end
            
            WAIT_TRIGG: begin
               if( counter <DELAY_CYCLES) begin
                  next_counter = counter + 1'b1;
               end 
               else if( tdc_trigg) begin
                  next_state = SEND_START;
               end
//                if (tdc_trigg) begin
//                    next_state = SEND_START;
//                end
            end
            
            SEND_START: begin
                next_tdc_start = 1'b1;
                next_state = WAIT_DELAY;
                next_counter = 32'd0;
            end
            
            WAIT_DELAY: begin
                next_tdc_start = 1'b1;
                if (counter < DELAY_CYCLES) begin
                    next_counter = counter + 1'b1;
                end else begin
                    next_state = SEND_STOP;
                end
            end
            
            SEND_STOP: begin
                next_tdc_start = 1'b1;
                next_tdc_stop = 1'b1;
                next_state = WAIT_INTB;
            end
            
            WAIT_INTB: begin
                next_tdc_stop = 1'b1;
                if (~tdc_intb) begin // Active low interrupt
                    next_state = READ_RESULTS;
                    next_config_step = 4'd0;
                end
            end
            
            READ_RESULTS: begin
                next_tdc_stop = 1'b1;
                if (spi_done) begin
                    // SPI transaction completed, store data and move to next read
                    case (config_step)
                        4'd0: next_time1_reg = spi_data_out;
                        4'd1: next_cal1_reg = spi_data_out;
                        4'd2: next_cal2_reg = spi_data_out;
                        default: next_state = RESET_STATE;
                    endcase
                    next_config_step = config_step + 1'b1;
                end else if (!spi_busy) begin
                    // SPI is idle, start next read transaction
                    case (config_step)
                        4'd0: begin
                            next_spi_addr = 8'h10; // TIME1
                            next_spi_start = 1'b1;
                            next_read_write = 1'b0;
                        end
                        4'd1: begin
                            next_spi_addr = 8'h1B; // CALIBRATION1
                            next_spi_start = 1'b1;
                            next_read_write = 1'b0;
                        end
                        4'd2: begin
                            next_spi_addr = 8'h1C; // CALIBRATION2
                            next_spi_start = 1'b1;
                            next_read_write = 1'b0;
                        end
                        default: begin
                            next_state = SEND_UART;
                            next_uart_byte_count = 8'd0;
                        end
                    endcase
                end
                // If spi_busy is true, just wait
            end
            
            // SEND_UART state (unchanged - already using uart_busy correctly):
            SEND_UART: begin
                if (uart_done) begin
                    // Transmission completed, move to next byte
                    next_uart_byte_count = uart_byte_count + 1'b1;
                end else if (!uart_busy) begin
                    // UART is idle, start next byte transmission
                    case (uart_byte_count)
                        8'd0: begin
                            next_uart_data = time1_reg[23:16];
                            next_uart_start = 1'b1;
                        end
                        8'd1: begin
                            next_uart_data = time1_reg[15:8];
                            next_uart_start = 1'b1;
                        end
                        8'd2: begin
                            next_uart_data = time1_reg[7:0];
                            next_uart_start = 1'b1;
                        end
                        8'd3: begin
                            next_uart_data = cal1_reg[23:16];
                            next_uart_start = 1'b1;
                        end
                        8'd4: begin
                            next_uart_data = cal1_reg[15:8];
                            next_uart_start = 1'b1;
                        end
                        8'd5: begin
                            next_uart_data = cal1_reg[7:0];
                            next_uart_start = 1'b1;
                        end
                        8'd6: begin
                            next_uart_data = cal2_reg[23:16];
                            next_uart_start = 1'b1;
                        end
                        8'd7: begin
                            next_uart_data = cal2_reg[15:8];
                            next_uart_start = 1'b1;
                        end
                        8'd8: begin
                            next_uart_data = cal2_reg[7:0];
                            next_uart_start = 1'b1;
                        end
                        8'd9: begin
                            next_uart_data = 8'h0A; // Line feed
                            next_uart_start = 1'b1;
                        end
                        default: next_state = DONE_STATE;
                    endcase
                end
                // If uart_busy is true, just wait
            end 
 
            
            DONE_STATE: begin
                // Stay here - measurement complete
            end
            
            default: begin
                next_state = RESET_STATE;
            end
        endcase
    end

endmodule
