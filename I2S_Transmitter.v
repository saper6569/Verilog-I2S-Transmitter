/*
	Author: Sanija Perera
	Date: 2026/08/17
	License: CC0 1.0 Universal
	
	This module is a customizable I²S transmitter that converts left/right audio 
	samples into a serial I²S data stream. It generates the required BCK and LRCK 
	signals from any given system clock using a fractional phase-accumulator 
	divider, while providing ready pulses to flag the loading of new audio samples.
	
	Module Parameters:
	WORD_SIZE
	- 	Controls the number of bits in each input audio sample.
	- 	Default: 16 bits.
	- 	Example: Setting WORD_SIZE = 24 allows 24-bit audio samples.
	
	SAMPLE_RATE
	- 	Controls the audio sample rate in samples per second.
	- 	Default: 44,100 Hz.
	- 	Example: SAMPLE_RATE = 48_000 produces a 48 kHz audio stream.
	
	CLOCK_FREQ
	- 	Specifies the frequency of the FPGA/system clock driving the module.
	- 	Used by the fractional clock divider to generate the required BCK frequency.
	- 	Default: 50 MHz.
	
	ACC_WIDTH
	- 	Controls the width of the phase accumulator used by the fractional clock divider.
	- 	A larger value provides finer frequency resolution and allows the desired 
		BCK frequency to be represented more accurately.
	- 	Default: 32 bits.
	
	How to Use the Module
	- 	This I²S module is used by connecting the system clock and left/right 
		audio sample inputs to the corresponding input ports and connecting BCK, 
		LRCK, and DOUT to the I²S-compatible audio device. 
	- 	The module should be instantiated with parameters matching the desired 
		audio format and the FPGA system clock frequency.
	- 	input_word_left and input_word_right inputs should contain the next left 
		and right audio samples, respectively. **Initialize as 0 in top level to 
		prevent on startup artifacts.
	- 	left_ready and right_ready signals indicate when the module is ready to 
		load a new sample, external logic should update the input when the 
		corresponding ready signal is flagged. 
	- 	The module automatically serializes the samples MSB-first through DOUT, 
		generates the required BCK, and alternates LRCK between the left and 
		right channels. 
	- 	The generated BCK, LRCK, and DOUT signals can then be connected directly 
		to the corresponding I²S inputs of an audio DAC, codec or amplifier.

	I provided a simple example that outputs a sine wave.
*/

module I2S_Transmitter
#(	parameter WORD_SIZE = 16,
	parameter SAMPLE_RATE = 44_100,
	parameter CLOCK_FREQ = 50_000_000,
	parameter ACC_WIDTH = 32 // Phase-accumulator width: bigger = finer frequency resolution
)
(
	input wire clk,
	input wire reset_n,
	// Two's-complement PCM audio samples, transmitted MSB-first.
	input wire [WORD_SIZE-1:0] input_word_left,
	input wire [WORD_SIZE-1:0] input_word_right,
	output reg BCK = 0,
	output reg LRCK = 0, // 0 = left, 1 = right
	output reg DOUT = 0,
	output reg left_ready = 0, // Pulses high for 1 clk when input_word_left is ready to be set.
	output reg right_ready = 0 // Pulses high for 1 clk when input_word_right is ready to be set.
);
	localparam BITS_PER_CHANNEL = 32;

	// BCK must toggle 2 (channels) * BITS_PER_CHANNEL * 2 (toggles/bit) times per sample period.
	// Kept as a plain integer (not `real`) -- fits comfortably in 32 bits for any sane audio rate.
	localparam integer BCK_TOGGLE_FREQ = 4 * BITS_PER_CHANNEL * SAMPLE_RATE;

	// PHASE_STEP/2^ACC_WIDTH * CLOCK_FREQ ~= BCK_TOGGLE_FREQ.
	// Computed with pure integer/vector arithmetic in a wide (64-bit) intermediate instead of
	// `real` + `**`, since Quartus's synthesis-time constant folder can mis-resolve the implicit
	// real-to-vector conversion of that pattern (silently collapsing it to 0 and, with it, the
	// entire design -- outputs "stuck at GND", 0 logic elements used).
	localparam [63:0] PHASE_STEP_NUM = (64'd1 * BCK_TOGGLE_FREQ) << ACC_WIDTH;
	localparam [ACC_WIDTH-1:0] PHASE_STEP = PHASE_STEP_NUM / CLOCK_FREQ;

	// Elaboration-time check: hardware can't make BCK_en faster than clk itself, so CLOCK_FREQ 
	// must exceed the required toggle rate.
	initial begin
		if (BCK_TOGGLE_FREQ >= CLOCK_FREQ) begin
			$error("CLOCK_FREQ (%0d) must be greater than 4*BITS_PER_CHANNEL*SAMPLE_RATE (%0d)", CLOCK_FREQ, BCK_TOGGLE_FREQ);
		end
		if (WORD_SIZE > BITS_PER_CHANNEL) begin
			$error("WORD_SIZE (%0d) must not exceed BITS_PER_CHANNEL (%0d)", WORD_SIZE, BITS_PER_CHANNEL);
		end
		if (PHASE_STEP == 0) begin
			$error("PHASE_STEP resolved to 0 -- BCK will never toggle. Check CLOCK_FREQ/SAMPLE_RATE/ACC_WIDTH.");
		end
	end

	// Buffer for channel data
	reg [WORD_SIZE-1:0] LEFT_WORD = 0;
	reg [WORD_SIZE-1:0] RIGHT_WORD = 0;

	reg [ACC_WIDTH-1:0] phase_acc = 0;
	reg [$clog2(BITS_PER_CHANNEL)-1:0] bit_counter = 0; // Bits shifted in current channel

	/*
	Fractional clock divider (phase accumulator): add PHASE_STEP every clk. BCK_en pulses on overflow. 
	Average pulse rate = PHASE_STEP/2^ACC_WIDTH * clk, which equals BCK_TOGGLE_FREQ.
	*/
	wire [ACC_WIDTH:0] phase_acc_next = phase_acc + PHASE_STEP;
	wire BCK_en = phase_acc_next[ACC_WIDTH];

	always @(posedge clk) begin
		if (!reset_n) begin
			phase_acc <= 0;
		end else begin
			phase_acc <= phase_acc_next[ACC_WIDTH-1:0];
		end
	end

	// BCK toggles every BCK_en pulse (this is the actual BCK clock).
	always @(posedge clk) begin
		if (!reset_n) begin
			BCK <= 0;
		end else if (BCK_en) begin
			BCK <= ~BCK;
		end
	end

	// Pulses for one clk cycle leading into the falling edge of BCK. Used for updating serial data.
	wire bit_tick = BCK_en && BCK;

	/*
	Update LRCK (word clock, 0 = left, 1 = right).
	Perform bit shifting of the active channel and send the MSB.
	Pulse channel ready flag for when new data can be written.
	Update channel data before serial output.
	*/
	always @(posedge clk ) begin
		// Reset ready for input flags.
		left_ready <= 1'b0;
		right_ready <= 1'b0;

		if (!reset_n) begin
			LRCK <= 0;
			DOUT <= 0;
			left_ready  <= 0;
			right_ready <= 0;
			bit_counter <= 0;

		end else if (bit_tick) begin
			// Place MSB of the active channel's word into the output bus and left shift the word.
			if (LRCK) begin
				DOUT <= RIGHT_WORD[WORD_SIZE-1];
				RIGHT_WORD <= RIGHT_WORD << 1;
			end else begin
				DOUT <= LEFT_WORD[WORD_SIZE-1];
				LEFT_WORD <= LEFT_WORD << 1;
			end

			// After last bit is shifted out toggle LRCK and reset counter.
			if (bit_counter >= (BITS_PER_CHANNEL - 1)) begin
				bit_counter <= 0;
				LRCK <= ~LRCK;

				// Latch a new word for the channel that is being switching into.
				if (LRCK) begin
					// Currently outputting RIGHT_WORD but switching to left next, so set LEFT_WORD.
					LEFT_WORD <= input_word_left;
					// Toggle to flag that input_word_left is ready to be set.
					left_ready <= 1'b1;
				end else begin
					// Currently outputting LEFT_WORD but switching to right next, so set RIGHT_WORD.
					RIGHT_WORD <= input_word_right;
					// Toggle to flag that input_word_right is ready to be set.
					right_ready <= 1'b1;
				end
			end else begin
				bit_counter <= bit_counter + 1;
			end
		end
	end
endmodule