
// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


// note. counter freq is half clk, because increments on clk.
`define CLK_FREQ        20000000


////////////////////

// TODO move these to common file.

// TODO - add these in mcu code also.  it gets too confusing otherwise.
`define SW_PC_SIGNAL    1
`define SW_PC_BOOT      0


// AZMUX PC-OUT select the hi
`define S1              ((1<<3)|(1-1))
`define S2          ((1<<3)|(2-1))

`define S7          ((1<<3)|(7-1))


`define AZMUX_PCOUT    `S1     // signal PC-OUT
