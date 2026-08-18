# Verilog-I2S-Transmitter
Simple customizable I²S transmitter that converts left/right audio samples into a serial I²S data stream. It generates the required BCK and LRCK signals from any given system clock using a fractional phase-accumulator divider, while providing ready pulses to flag the loading of new audio samples.

## Module Parameters:
### WORD_SIZE
- 	Controls the number of bits in each input audio sample.
- 	Default: 16 bits.
- 	Example: Setting WORD_SIZE = 24 allows 24-bit audio samples.
### SAMPLE_RATE
- 	Controls the audio sample rate in samples per second.
- 	Default: 44,100 Hz.
- 	Example: SAMPLE_RATE = 48_000 produces a 48 kHz audio stream.
### CLOCK_FREQ
- 	Specifies the frequency of the FPGA/system clock driving the module.
- 	Used by the fractional clock divider to generate the required BCK frequency.
- 	Default: 50 MHz.
### ACC_WIDTH
- 	Controls the width of the phase accumulator used by the fractional clock divider.
- 	A larger value provides finer frequency resolution and allows the desired BCK frequency 
  to be represented more accurately.
- 	Default: 32 bits.

## How to Use the Module
- 	This I²S module is used by connecting the system clock and left/right audio sample inputs 
  to the corresponding input ports and connecting BCK, LRCK, and DOUT to the I²S-compatible audio device. 
- 	The module should be instantiated with parameters matching the desired audio format and 
  the FPGA system clock frequency.
- 	input_word_left and input_word_right inputs should contain the next left and right audio 
  samples, respectively. **Initialize as 0 in top level to prevent on startup artifacts.
- 	left_ready and right_ready signals indicate when the module is ready to load a new sample; 
  external logic should update the input when the appropriate ready signal is asserted. 
- 	The module automatically serializes the samples MSB-first through DOUT, generates the 
  required BCK, and alternates LRCK between the left and right channels. 
- 	The generated BCK, LRCK, and DOUT signals can then be connected directly to the corresponding 
  I²S inputs of an audio DAC, codec or amplifier.

I provided a simple example that outputs a sine wave.
