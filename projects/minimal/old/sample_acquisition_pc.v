/*

  - only switch the pc switch. not the azmux. for charge testing.
  - code is quite similar to the az mux. sample acquisition.

*/


// implicit identifiers are only caught when modules have been instantiated
`default_nettype none



// `include "defines.v"



////////////////////


`define SW_PC_SIGNAL    1
`define SW_PC_BOOT      0


// AZMUX PC-OUT select the hi
// `define S1              ((1<<3)|(1-1))
// `define AZMUX_HI_VAL    `S1     // PC-OUT



module sample_acquisition_pc (

  // remember hi mux is not manipulated, or passed into this module.
  // inistead the hi signal is seleced by the AZ mux, via the pre-charge switch

  input   clk,
  input   reset_n,

  // lo mux input to use.
  // input [  4-1 : 0 ] azmux_lo_val,


/*
    TODO - mar 2024. rename these with module prefix
      sa_p_clk_sample_duration_i_i
      or
      sa_clk_sample_duration_i_i
      actually not sure.
*/

  // modulation_az hardcodes the hi_val . since does not change for normal az operation
  input [ 32-1 : 0 ] p_clk_sample_duration_i,  // 32/31 bit nice. for long sample....  wrongly named it is counter_sample_duration_i. not clk...

  input [24-1:0]    p_clk_count_precharge_i,

  /// outputs.
  output reg  sw_pc_ctl_o,
  // output reg [ 4-1:0 ] azmux,

  output reg led0_o,
  output reg [ 8-1:0]  monitor_o,

);

  reg [7-1:0]   state = 0 ;     // should expose in module, not sure.

  reg [31:0]    clk_count_down;           // clk_count for the current phase. using 31 bitss, gives faster timing spec.  v 24 bits. weird. ??? 36MHz v 32MHz



  // this would be an async signal???
  wire run = 1;

  always @(posedge clk  or posedge reset_n )
   if(reset_n)
    begin
      // set up next state, for when reset goes hi.
      state           <= 0;
    end
    else
    begin

      // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;


      case (state)

        // precharge switch - protects the signal. from the charge-injection of the AZ switch.
          0:
          // having a state like, this may be useful for debuggin, because can put a pulse on the monitor_o.
          state <= 1;

        // switch pre-charge switch to boot to protect signal
        1:
          begin
            state           <= 15;
            clk_count_down  <= p_clk_count_precharge_i;
            sw_pc_ctl_o       <= `SW_PC_BOOT;
            // azmux           <=  azmux_lo_val;       // should be defined. or set in async reset. not left over state.
            monitor_o         <= { 8 { 1'b0 } } ;     // reset
          end
        15:
          if(clk_count_down == 0)
            state <= 2;


        ////////////////////////////
        // switch azmux from LO to PC OUT (BOOT).    (signal is currently protected by pc)  - the 'precharge phase' or settle phase
        // precharge phase.
        2:
            begin
              state           <= 25;
              clk_count_down  <= p_clk_count_precharge_i;  // normally pin s1
              // azmux          <= `AZMUX_HI_VAL;
              monitor_o[0]      <= 1;
            end
        25:
          if(clk_count_down == 0)
            state <= 3;


        /////////////////////////
        // switch pc-switch from BOOT to signal. take hi measure
        3:
          begin
            state           <= 35;
            clk_count_down  <= p_clk_sample_duration_i;
            sw_pc_ctl_o       <= `SW_PC_SIGNAL;
            led0_o            <= 1;
            monitor_o[1]      <= 1;
          end
        35:
          if(clk_count_down == 0)
            state <= 4;

        // switch pre-charge switch back to boot to protect signal again
        4:
          begin
            state           <= 45;
            clk_count_down  <= p_clk_count_precharge_i; // time less important here
            sw_pc_ctl_o       <= `SW_PC_BOOT;
            monitor_o[1]      <= 0;
          end
        45:
          if(clk_count_down == 0)
            state <= 5;

        /////////////////////////
        // switch az mux to lo.   take lo measurement
        5:
          begin
            state           <= 55;
            clk_count_down  <= p_clk_sample_duration_i;
            // azmux           <= azmux_lo_val;
            led0_o            <= 0;
            monitor_o[0]      <= 0;
          end
        55:
          if(clk_count_down == 0)
            state <= 6;


        6:
          if(run )        // place at end.
            state <= 2;


      endcase
    end
endmodule



