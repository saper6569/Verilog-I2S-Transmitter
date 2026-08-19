module sine_LUT #(
    parameter RESOLUTION = 16,
    parameter real AMPLITUDE = 1,
    parameter real PHASE_SHIFT = 0.0,
    parameter SAMPLES = 512
) (
    input wire [$clog2(SAMPLES)-1:0] index,
    output wire signed [RESOLUTION-1:0] value
);
    reg signed [RESOLUTION-1:0] LUT [SAMPLES-1:0];

    integer i;
    real temp;
    real PI = 3.1415926535;

    initial begin

        if (AMPLITUDE > 1.0) begin
            $error("AMPLITUDE (%0f) must be <= 1", AMPLITUDE);
        end

        if (AMPLITUDE < 0.0) begin
            $error("AMPLITUDE (%0f) must be > 0", AMPLITUDE);
        end

        for (i = 0; i < SAMPLES; i = i + 1) begin
            temp = ((2.0 * PI) / SAMPLES) * i + PHASE_SHIFT;
            LUT[i] = AMPLITUDE * $sin(temp) * ((2**(RESOLUTION-1)) - 1) + 0.5;
        end
    end

    assign value = LUT [index];
    
endmodule