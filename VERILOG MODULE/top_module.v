

module top_module (
    input wire clk,              // 100MHz board clock
    input wire rst_btn,          // Reset button (active low on Basys3)
    
    // TDC7200 connections
    output wire tdc_en,
    output wire tdc_start,
    output wire tdc_stop,
    output wire tdc_clk,         // 10MHz clock to TDC
    input wire tdc_intb,
    input wire tdc_trigg,
    
    // SPI connections to TDC7200
    output wire spi_clk,
    output wire spi_mosi,
    output wire spi_cs_n,
    input wire spi_miso,
    
    // UART
    output wire uart_tx,
    
    // State
    output wire [3:0] led_state
);

    // Reset handling (active high)
    wire rst = ~rst_btn;
    
    // Clock generation using counters
    reg [2:0] clk_counter;       // 3-bit counter for divide by 5
    reg clk_10mhz;               // Generated 10MHz clock
    
    // 20MHz clock generation (100MHz / 10 = 10MHz)
    always @(posedge clk) begin
        if (rst) begin
            clk_counter <= 3'b000;
            clk_10mhz <= 1'b0;
            
        end else begin
            if (clk_counter == 3'd4) begin
                clk_counter <= 3'b000;
                clk_10mhz <= ~clk_10mhz;    // Toggle clock every 5 cycles
            end else begin
                clk_counter <= clk_counter + 1'b1;
            end
        end
    end
    
    // Connect the generated clock to TDC
    assign tdc_clk = clk_10mhz;
    
    // System uses the main 100MHz clock for internal logic
    wire system_clk = clk;
    
    // Internal signals
    wire spi_start, spi_done, spi_busy,read_write;
    wire [7:0] spi_addr;
    wire [7:0] spi_data_in;
    wire [23:0] spi_data_out;
    wire uart_start, uart_done, uart_busy;
    wire [7:0] uart_data;
    
    // Module instantiations - ALL use the 100MHz input clock
    (* dont_touch = "true" *) spi_master spi_inst (
        .clk(system_clk),        // Use 100MHz input clock
        .rst(rst),
        .start(spi_start),
        .addr(spi_addr),
        .data_in(spi_data_in),
        .miso(spi_miso),
        .next_done(spi_done),
        .data_out(spi_data_out),
        .sclk(spi_clk),
        .mosi(spi_mosi),
        .cs_n(spi_cs_n),
        .spi_busy(spi_busy),
        .read_write(read_write)
    );
    
    uart_tx uart_inst (
        .clk(system_clk),        // Use 100MHz input clock
        .rst(rst),
        .start(uart_start),
        .data(uart_data),
        .done(uart_done),
        .tx(uart_tx),
        .tx_busy(uart_busy)
    );
    
    tdc_controller controller_inst (
        .clk(system_clk),        // Use 100MHz input clock
        .rst(rst),
        .tdc_intb(tdc_intb),
        .tdc_trigg(tdc_trigg),
        .spi_done(spi_done),
        .spi_busy(spi_busy),
        .spi_data_out(spi_data_out),
        .uart_done(uart_done),
        .uart_busy(uart_busy),
        .tdc_en(tdc_en),
        .tdc_start(tdc_start),
        .tdc_stop(tdc_stop),
        .spi_start(spi_start),
        .spi_addr(spi_addr),
        .spi_data_in(spi_data_in),
        .uart_start(uart_start),
        .uart_data(uart_data),
        .led_state(led_state),
        .read_write(read_write)
    );
