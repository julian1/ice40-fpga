
// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


// note. counter freq is half clk, because increments on clk.
`define CLK_FREQ        20000000


////////////////////


/*
  fpga should not include/have any concept of these reg/mux values, but it is
  helpful to populate the registers with some default vals for default test/start behaviors
*/


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


  uint32_t    code          : 4;  // 0      // unused/reserved

  uint32_t    pc_protect    : 2;  // 4      // pc state during azmux switching
  uint32_t    pc_sample     : 2;  // 6      // pc state during sample
  uint32_t    azmux         : 4;  // 8     // azmux state for sample

  uint32_t    next_idx      : 3;  // 12

  uint32_t                  : 1;  // 15 + 1 = 16

  /////////////////////////////
  // decode flags

  uint32_t    hi            : 1;  // 16     // TODO. bad name.  hi == input signal/sample. or zero
  uint32_t    convert       : 1;  // 17     // convert to reading on this input
  uint32_t                  : 6;  // 18 + 6 =  24

  /////////////////////////////
  // control flags

  uint32_t    oob_aperture  : 1;  // 24     // oob.   use oob aperture.
  uint32_t    dither_cm_dac : 1;  // 25
  uint32_t    dither_runup  : 1;  // 26


  uint32_t                  : 5;  // 27 + 5 = 32

*/

`define TERM_CODE_SLICE        0 +: 4
`define TERM_PC_PROTECT_SLICE  4 +: 2
`define TERM_PC_SAMPLE_SLICE   6 +: 2

`define TERM_AZMUX_SLICE       8 +: 4

`define TERM_NEXT_IDX_SLICE    12 +: 3

// distinguish oob flags, from actual aperture control
// to support other oob actions
`define TERM_OOB                24
`define TERM_SECOND             25

// control the aperture
`define TERM_APERTURE2          26






