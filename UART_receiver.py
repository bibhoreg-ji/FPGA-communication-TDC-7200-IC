import serial

# ==========================================================
# UART Configuration
# ==========================================================

PORT = "COM6"  # Change this
BAUDRATE = 115200

CLOCK_FREQ = 10_000_000  # 10 MHz
CLOCK_PERIOD = 1 / CLOCK_FREQ
CAL2_PERIODS = 10

# ==========================================================
# Open Serial Port
# ==========================================================

ser = serial.Serial(port=PORT, baudrate=BAUDRATE, timeout=1)

print(f"Listening on {PORT} at {BAUDRATE} baud...\n")

packet = []

while True:

    byte = ser.read(1)

    if len(byte) == 0:
        continue

    value = byte[0]

    # End of packet
    if value == 0x0A:

        # ==================================================
        # Your FPGA currently sends:
        #
        # TIME1
        # CAL1
        # CAL2
        #
        # Total = 9 bytes
        # ==================================================

        if len(packet) >= 9:

            TIME1 = (packet[0] << 16) | (packet[1] << 8) | packet[2]

            CAL1 = (packet[3] << 16) | (packet[4] << 8) | packet[5]

            CAL2 = (packet[6] << 16) | (packet[7] << 8) | packet[8]

            # ==============================================
            # TDC7200 Calculations
            # ==============================================

            calCount = (CAL2 - CAL1) / (CAL2_PERIODS - 1)

            normLSB = CLOCK_PERIOD / calCount

            # ------------------------------------------------
            # MODE 2 Simplified Formula
            #
            # Since you are not reading:
            # TIME2
            # CLOCK_COUNT1
            #
            # We use:
            #
            # TOF ≈ TIME1 × normLSB
            # ------------------------------------------------

            TOF = TIME1 * normLSB

            # ==============================================
            # Print Results
            # ==============================================

            print("======================================")
            print("TDC7200 Measurement")
            print("======================================")

            print(f"TIME1 = {TIME1}")
            print(f"CAL1  = {CAL1}")
            print(f"CAL2  = {CAL2}")

            print("--------------------------------------")

            print(f"calCount = {calCount:.3f}")
            print(f"normLSB  = {normLSB*1e12:.3f} ps")

            print("--------------------------------------")

            print(f"TOF = {TOF*1e9:.6f} ns")

            print("======================================\n")

        else:
            print("Incomplete packet received")

        packet = []

    else:
        packet.append(value)
