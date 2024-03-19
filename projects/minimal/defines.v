
// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


// note. counter freq is half clk, because increments on clk.
`define CLK_FREQ        20000000


////////////////////


/*
  fpga should not include/have any concept of these reg/mux values, but it is
  helpful to populate the registers with some default vals for default test/start behaviors
*/

`define S1          ((1<<3)|(1-1))
`define S2          ((1<<3)|(2-1))
`define S3          ((1<<3)|(3-1))

`define S7          ((1<<3)|(7-1))
`define S8          ((1<<3)|(8-1))


