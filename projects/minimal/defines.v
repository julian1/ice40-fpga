
// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


// note. counter freq is half clk, because increments on clk.
`define CLK_FREQ        20000000


////////////////////


/*
  fpga should not include/have any concept of these reg/mux values, but it is
  helpful to populate the registers with some default vals for default test/start behaviors
*/

`define SOFF        0
// `define S1          ((1-1)<<1|1'b1)     // { 3'b0, 1'b1 }
`define S1          { 3'd0, 1'b1 }
`define S2          { 3'd1, 1'b1 }
`define S3          { 3'd2, 1'b1 }
`define S4          { 3'd3, 1'b1 }
`define S5          { 3'd4, 1'b1 }
`define S6          { 3'd5, 1'b1 }
`define S7          { 3'd6, 1'b1 }
`define S8          { 3'd7, 1'b1 }


/*
`define S1          ((1<<3)|(1-1))
`define S2          ((1<<3)|(2-1))
`define S3          ((1<<3)|(3-1))
`define S4          ((1<<3)|(4-1))
`define S5          ((1<<3)|(5-1))
`define S6          ((1<<3)|(6-1))
`define S7          ((1<<3)|(7-1))
`define S8          ((1<<3)|(8-1))

*/
