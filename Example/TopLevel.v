module TopLevel #(
    parameter AMPLITUDE = 0.5, 
    parameter SAMPLES = 360,
    parameter SIN_FREQ = 300,
    parameter WORD_SIZE = 16,
    parameter ACC_WIDTH = 32,
    parameter CLOCK_FREQ = 50_000_000
) (
    input wire clk,
    input wire reset_n,
    output wire BCK,
    output wire LRCK,
    output wire DOUT
);

    reg [$clog2(SAMPLES)-1:0] sin_index = 0;
    wire signed [WORD_SIZE-1:0] sin_value;

    sine_LUT #(.RESOLUTION(WORD_SIZE), .AMPLITUDE(AMPLITUDE)) sin (
        .index(sin_index),
        .value(sin_value)
    );

    localparam real PHASE_STEP_REAL = (SIN_FREQ * (2.0 ** ACC_WIDTH)) / CLOCK_FREQ;
    localparam [ACC_WIDTH-1:0] PHASE_STEP = PHASE_STEP_REAL;
    reg [ACC_WIDTH-1:0] phase_acc = 0;

    wire [ACC_WIDTH:0] phase_acc_next = phase_acc + PHASE_STEP;
    wire update_sin_index = phase_acc_next[ACC_WIDTH];

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            phase_acc <= 0;
        else
            phase_acc <= phase_acc_next[ACC_WIDTH-1:0];
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sin_index <= 0;
        end else if (update_sin_index) begin
            if (sin_index >= SAMPLES - 1)
                sin_index <= 0;
            else
                sin_index <= sin_index + 1;
        end
    end

    wire left_ready;
    wire right_ready;

    wire signed [WORD_SIZE-1:0] input_word_left = sin_value;
    reg  signed [WORD_SIZE-1:0] input_word_right = 0; // mono: right channel silent

    I2S_Transmitter #(
        .WORD_SIZE(WORD_SIZE),
        .SAMPLE_RATE(44_100),
        .CLOCK_FREQ(CLOCK_FREQ),
        .ACC_WIDTH(ACC_WIDTH)
    ) i2s_transmitter (
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

endmodule