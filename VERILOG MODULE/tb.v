`timescale 1ns / 1ps

module top_module_tb;

    // =========================================================
    // Clock / Reset
    // =========================================================
    
    reg clk;
    reg rst_btn;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;   // 100MHz clock
    end

    // =========================================================
    // DUT I/O
    // =========================================================
    
    wire tdc_en;
    wire tdc_start;
    wire tdc_stop;
    wire tdc_clk;

    reg tdc_intb;
    reg tdc_trigg;

    wire spi_clk;
    wire spi_mosi;
    wire spi_cs_n;
    reg  spi_miso;

    wire uart_tx;
    wire [3:0] led_state;

    // =========================================================
    // DUT
    // =========================================================
    
    top_module DUT (
        .clk(clk),
        .rst_btn(rst_btn),

        .tdc_en(tdc_en),
        .tdc_start(tdc_start),
        .tdc_stop(tdc_stop),
        .tdc_clk(tdc_clk),

        .tdc_intb(tdc_intb),
        .tdc_trigg(tdc_trigg),

        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_cs_n(spi_cs_n),
        .spi_miso(spi_miso),

        .uart_tx(uart_tx),

        .led_state(led_state)
    );

    // =========================================================
    // SPI Slave Emulation
    // =========================================================

    reg [23:0] spi_response_data;
    reg [4:0] spi_bit_count;

    initial begin
        spi_response_data = 24'h123456;
        spi_bit_count = 0;
    end

    // Send SPI data back to master on negative edge
    always @(negedge spi_clk) begin

        if (!spi_cs_n) begin

            // After command phase (8 bits)
            if (spi_bit_count >= 8 && spi_bit_count < 32) begin
                spi_miso <= spi_response_data[23];
                spi_response_data <= {spi_response_data[22:0],1'b0};
            end

            spi_bit_count <= spi_bit_count + 1'b1;

        end else begin
            spi_bit_count <= 0;

            // Reload fake data
            spi_response_data <= 24'hABCDEF;
        end
    end

    // =========================================================
    // UART Monitor
    // =========================================================

    reg [7:0] uart_rx_byte;
    integer uart_bit_index;

    initial begin
        uart_rx_byte = 8'd0;
        uart_bit_index = 0;
    end

    // Simple UART decoder
    initial begin

        forever begin

            // Wait for start bit
            @(negedge uart_tx);

            #(8680); // Half bit + align

            uart_rx_byte = 8'd0;

            // Sample 8 bits
            repeat (8) begin
                #(8680);
                uart_rx_byte = {uart_tx, uart_rx_byte[7:1]};
            end

            #(8680);

            $display("UART RX BYTE = 0x%h (%0d) at time %0t",
                     uart_rx_byte,
                     uart_rx_byte,
                     $time);

        end
    end

    // =========================================================
    // Stimulus
    // =========================================================

    initial begin

        // Initialize
        rst_btn   = 0;
        tdc_intb  = 1;
        tdc_trigg = 0;
        spi_miso  = 0;

        // Hold reset
        #1000;

        // Release reset
        rst_btn = 1;

        $display("Reset Released");

        // Wait until TDC enabled
        wait(tdc_en == 1);

        $display("TDC Enabled at %0t", $time);

        // Wait some time
        #500000;

        // Trigger TDC
        tdc_trigg = 1;

        $display("TDC Trigger Asserted");

        #100;

        tdc_trigg = 0;

        // Wait until STOP pulse generated
        wait(tdc_stop == 1);

        $display("STOP Pulse Generated");

        // Simulate measurement completion
        #1000;

        tdc_intb = 0;

        $display("TDC Interrupt Asserted");

        #1000;

        tdc_intb = 1;

        // Run long enough for UART transmission
        #5000000;

        $display("Simulation Complete");

        $finish;
    end

    // =========================================================
    // Monitoring
    // =========================================================

    initial begin

        $monitor(
            "TIME=%0t | STATE=%0d | SPI_CS=%b | SPI_CLK=%b | UART_TX=%b | START=%b | STOP=%b",
            $time,
            led_state,
            spi_cs_n,
            spi_clk,
            uart_tx,
            tdc_start,
            tdc_stop
        );

    end

endmodule
