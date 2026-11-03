# Oscillator and the dedicated LaC1 divided clock.
create_clock -name OSC_CLK {OSC_CLK} -period 20.000 -waveform {0 10.000}
create_clock -name core_clk {core_clk} -period 320.000 -waveform {0 160.000}
