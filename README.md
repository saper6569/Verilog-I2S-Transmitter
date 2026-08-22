# Verilog I2S Transmitter

A synthesizable Verilog implementation of an I2S serial audio transmitter. The
module accepts independent left and right two's-complement PCM samples and
outputs the I2S bit clock, left/right clock, and serial data signals. BCK is
derived from the FPGA system clock with a fractional phase accumulator, so the
design does not require a separate audio clock.

## Features

- Configurable sample width, sample rate, system clock frequency, and divider resolution
- 32-bit I2S time slot for each channel
- MSB-first serial output
- Left/right channel selection with `LRCK` (`0` = left, `1` = right)
- One-clock `left_ready` and `right_ready` pulses for loading new samples
- Integer-only clock-divider calculation for synthesis compatibility
- MIT licensed

## Repository Contents

| File | Description |
| --- | --- |
| `I2S_Transmitter.v` | Parameterized I2S transmitter module |
| `Example/I2S_Test_Square_TopLevel.v` | Example top level that generates a 440 Hz square wave |
| `LICENSE` | MIT license |

## Module Interface

```verilog
module I2S_Transmitter #(
		parameter WORD_SIZE   = 16,
		parameter SAMPLE_RATE = 44_100,
		parameter CLOCK_FREQ  = 50_000_000,
		parameter ACC_WIDTH   = 32
) (
		input  wire                  clk,
		input  wire                  reset_n,
		input  wire [WORD_SIZE-1:0]  input_word_left,
		input  wire [WORD_SIZE-1:0]  input_word_right,
		output reg                   BCK,
		output reg                   LRCK,
		output reg                   DOUT,
		output reg                   left_ready,
		output reg                   right_ready
);
```

### Inputs

- `clk`: FPGA/system clock.
- `reset_n`: Active-low synchronous reset. Hold low during initialization.
- `input_word_left`: Next left-channel PCM sample.
- `input_word_right`: Next right-channel PCM sample.

Samples are interpreted as two's-complement values and transmitted MSB-first.
Initialize both sample inputs to zero, or to a known valid sample, before
releasing reset to avoid startup artifacts.

### Outputs

- `BCK`: I2S bit clock. It toggles twice for every transmitted bit.
- `LRCK`: Channel/word clock. Low selects the left channel; high selects the
	right channel.
- `DOUT`: Serial PCM data output.
- `left_ready`: One `clk`-cycle pulse when the left input sample is captured for
	the next left-channel slot.
- `right_ready`: One `clk`-cycle pulse when the right input sample is captured
	for the next right-channel slot.

The ready signals are strobes, not levels. External logic should update the
corresponding input sample in response to the appropriate pulse and keep the
input stable until the next opportunity to load it.

## Parameters

| Parameter | Default | Description |
| --- | ---: | --- |
| `WORD_SIZE` | `16` | Number of meaningful PCM bits in each input sample. Must be no greater than 32. |
| `SAMPLE_RATE` | `44_100` | Audio sample rate in samples per second. |
| `CLOCK_FREQ` | `50_000_000` | Frequency of `clk` in Hz. |
| `ACC_WIDTH` | `32` | Phase-accumulator width. Larger values provide finer BCK frequency resolution. |

Each channel occupies a fixed 32-bit slot, regardless of `WORD_SIZE`. For a
16-bit sample, the 16 sample bits are sent first and the remaining slot bits
are zero-filled by shifting the registered word. The implementation therefore
supports sample widths up to 32 bits, but it does not provide a configurable
slot width.

The required BCK toggle frequency is:

```text
BCK toggle frequency = 4 * 32 * SAMPLE_RATE
```

`CLOCK_FREQ` must be greater than this value. At elaboration, the module reports
an error if the clock is too slow, `WORD_SIZE` is greater than 32, or the
calculated phase step is zero.

## Instantiation

```verilog
I2S_Transmitter #(
		.WORD_SIZE(16),
		.SAMPLE_RATE(44_100),
		.CLOCK_FREQ(50_000_000),
		.ACC_WIDTH(32)
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
```

Connect `BCK`, `LRCK`, and `DOUT` to the matching inputs on an I2S DAC, codec,
or amplifier. Confirm the receiving device's expected slot width and LRCK
polarity before connecting hardware.

## Example

`Example/I2S_Test_Square_TopLevel.v` instantiates the transmitter with the
default 16-bit, 44.1 kHz format and generates a 440 Hz square wave on both
channels. It updates the sample generator when `left_ready` pulses and exposes
`BCK`, `LRCK`, and `DOUT` at the top level.

The example can be used as a starting point for an FPGA project. Add both
Verilog source files to the project, connect `clk` and `reset_n`, and assign the
three I2S outputs to the FPGA pins connected to the audio device.

## License

Copyright (c) 2026 Sanija Perera.

This project is licensed under the MIT License. See [LICENSE](LICENSE) for the
full text.
