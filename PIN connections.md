# Basys3 FPGA ↔ TDC7200 Connection Guide

---

# System Overview

This project interfaces the Basys3 FPGA board with the TDC7200 Time-to-Digital Converter using:

- SPI communication
- START/STOP timing signals
- UART output for measurement data

---

# Basys3 PMOD Pinout

![Basys3 PMOD Pinout](fpga.png)

The PMOD headers used in this project are:

- JA
- JB

---

# FPGA Board

- Board: Basys3
- FPGA: Xilinx Artix-7
- Logic Level: 3.3V LVCMOS

---

# Clock Connections

| FPGA Signal | FPGA Pin | TDC7200 Signal | Direction | Description                  |
| ----------- | -------- | -------------- | --------- | ---------------------------- |
| clk         | W5       | —              | Input     | 100MHz onboard clock         |
| tdc_clk     | J1       | CLOCK          | Output    | 10MHz reference clock to TDC |

---

# Reset

| FPGA Signal | FPGA Pin | Description              |
| ----------- | -------- | ------------------------ |
| rst_btn     | R2       | Basys3 BTN0 reset button |

---

# SPI Interface

| FPGA Signal | FPGA Pin | PMOD Header | TDC7200 Pin | Direction  | Description |
| ----------- | -------- | ----------- | ----------- | ---------- | ----------- |
| spi_clk     | C15      | JB9         | SCLK        | FPGA → TDC | SPI Clock   |
| spi_cs_n    | C16      | JB10        | CSB         | FPGA → TDC | Chip Select |
| spi_mosi    | A17      | JB8         | DIN         | FPGA → TDC | SPI MOSI    |
| spi_miso    | A15      | JB7         | DOUT        | TDC → FPGA | SPI MISO    |

---

# TDC Control Signals

| FPGA Signal | FPGA Pin | PMOD Header | TDC7200 Pin | Direction  | Description     |
| ----------- | -------- | ----------- | ----------- | ---------- | --------------- |
| tdc_clk     | J1       | JA1         | CLOCK       | FPGA → TDC | Reference clock |
| tdc_en      | L2       | JA2         | ENABLE      | FPGA → TDC | Enable TDC      |
| tdc_start   | J3       | JXAC1       | START       | FPGA → TDC | START pulse     |
| tdc_stop    | L3       | JXAC2       | STOP        | FPGA → TDC | STOP pulse      |

---

# TDC Status Signals

| FPGA Signal | FPGA Pin | PMOD Header | TDC7200 Pin | Direction  | Description      |
| ----------- | -------- | ----------- | ----------- | ---------- | ---------------- |
| tdc_intb    | J2       | JA3         | INTB        | TDC → FPGA | Interrupt output |
| tdc_trigg   | G2       | JA4         | TRIGG       | TDC → FPGA | Trigger output   |

---

# UART Connection

| FPGA Signal | FPGA Pin | Description |
| ----------- | -------- | ----------- |
| uart_tx     | A18      | USB-UART TX |

UART Configuration:

- Baud Rate: 115200
- Data Bits: 8
- Stop Bits: 1
- Parity: None

---

# LED State Indicators

| Signal       | FPGA Pin | LED |
| ------------ | -------- | --- |
| led_state[0] | U16      | LD0 |
| led_state[1] | E19      | LD1 |
| led_state[2] | U19      | LD2 |
| led_state[3] | V19      | LD3 |

---

# Complete Wiring Summary

## SPI Wiring

| Basys3 FPGA | PMOD | TDC7200 |
| ----------- | ---- | ------- |
| spi_clk     | JB9  | SCLK    |
| spi_cs_n    | JB10 | CSB     |
| spi_mosi    | JB8  | DIN     |
| spi_miso    | JB7  | DOUT    |

---

## Timing Signal Wiring

| Basys3 FPGA | PMOD  | TDC7200 |
| ----------- | ----- | ------- |
| tdc_clk     | JA1   | CLOCK   |
| tdc_en      | JA2   | ENABLE  |
| tdc_start   | JXAC1 | START   |
| tdc_stop    | JXAC2 | STOP    |

---

## Status Signal Wiring

| Basys3 FPGA | PMOD | TDC7200 |
| ----------- | ---- | ------- |
| tdc_intb    | JA3  | INTB    |
| tdc_trigg   | JA4  | TRIGG   |

---

# Power Connections

| Signal      | Connection |
| ----------- | ---------- |
| TDC7200 VDD | 3.3V       |
| TDC7200 GND | FPGA GND   |

Important:

- FPGA and TDC7200 must share common ground.
- All signals are 3.3V LVCMOS compatible.

---

# SPI Timing

SPI Mode:

- CPOL = 0
- CPHA = 0

SPI Clock Frequency:

- 2.5 MHz

---

# TDC Operation Sequence

1. FPGA enables TDC7200
2. FPGA configures TDC7200 through SPI
3. FPGA sends START pulse
4. FPGA waits fixed delay
5. FPGA sends STOP pulse
6. TDC7200 measures time interval
7. FPGA reads TIME1/CALIBRATION registers
8. FPGA transmits measurement over UART

---

# UART Data Packet Format

The FPGA sends:

| Bytes    | Data           |
| -------- | -------------- |
| Byte 0-2 | TIME1          |
| Byte 3-5 | CALIBRATION1   |
| Byte 6-8 | CALIBRATION2   |
| Byte 9   | 0x0A (newline) |

All measurement registers are 24-bit values.

---

# Notes

- Internal FPGA logic runs at 100MHz.
- TDC reference clock runs at 10MHz.
- SPI clock is generated internally at 2.5MHz.
- UART output can be monitored using:
  - PuTTY
  - TeraTerm
  - RealTerm
  - Python PySerial
