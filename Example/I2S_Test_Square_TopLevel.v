/*
 * Author: Sanija Perera
 * Date: 2026/08/17
 * License: MIT
 */

module TopLevel_SquareTest #(
    parameter WORD_SIZE = 16,
    parameter SAMPLE_RATE = 44_100,
    parameter CLOCK_FREQ = 50_000_000,
    parameter ACC_WIDTH = 32,

    // Square-wave frequency
    parameter FREQUENCY   = 440
)(
    input wire clk,
    input wire reset_n,

    output wire BCK,
    output wire LRCK,
    output wire DOUT
);

    reg [WORD_SIZE-1:0] input_word_left;
    reg [WORD_SIZE-1:0] input_word_right;
    wire left_ready;
    wire right_ready;

    reg [ACC_WIDTH-1:0] phase_accumulator;
    localparam [ACC_WIDTH-1:0] PHASE_INCREMENT = (FREQUENCY * (64'd1 << ACC_WIDTH)) / SAMPLE_RATE;

    // I2S transmitter
    I2S_Transmitter #(
        .WORD_SIZE(WORD_SIZE),
        .SAMPLE_RATE(SAMPLE_RATE),
        .CLOCK_FREQ(CLOCK_FREQ),
        .ACC_WIDTH(ACC_WIDTH)
    ) i2s_tx (
        .clk(clk),
        .reset_n(reset_n),
        .input_word_left(input_word_left),
        .input_word_right(input_word_right),

        .BCK(BCK),
        .LRCK(LRCK),
        .DOUT(DOUT),

        .left_ready(left_ready),
        .right_ready(right_ready)
    );

    // Square-wave generator
    always @(posedge clk) begin
        if (!reset_n) begin
            phase_accumulator <= {ACC_WIDTH{1'b0}};
            input_word_left  <= 16'h7FFF;
            input_word_right <= 16'h7FFF;
        end
        else begin
            if (left_ready) begin
                // Advance phase
                phase_accumulator <= phase_accumulator + PHASE_INCREMENT;
                // Use phase MSB as square-wave output
                if (phase_accumulator[ACC_WIDTH-1] == 1'b0) begin
                    input_word_left  <= 16'h7FFF;
                    input_word_right <= 16'h7FFF;
                end
                else begin
                    input_word_left  <= 16'h8000;
                    input_word_right <= 16'h8000;
                end
            end
        end
    end
endmodule