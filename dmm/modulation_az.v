/*

  we have the two clk transitions. but it makes it clearer to read.


  TODO - change name 'zero' -> 'lo'.  not sure.

  TODO - change 'active'   to 'mode'

          eg. normal AZ. where we switch between SIG/ZERO

*/


// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


`define CLK_FREQ        20000000



////////////////////

// TODO this value needs the EN pin set.

`define MUX_AZ_PC_OUT_PIN   4'b1000   // AZ switch pin muxes pc-out.

`define SW_PC_SIGNAL    1
`define SW_PC_BOOT      0






module modulation_az (

  // remember hi mux is not manipulated, or passed into this module.
  // inistead the hi signal is seleced by the AZ mux, via the pre-charge switch

  input   clk,
  input   reset,

  // lo mux input to use.
  input [  4-1 : 0 ] az_mux_val,

  /// outputs.
  output reg  sw_pc_ctl,
  output reg [ 4-1:0 ] azmux ,       // change name   az lo value.

  output reg led0,
  output reg [ 8-1:0]   monitor,

);



  // localparam x = 1;


  // pack and unpack monitor header. should be register.

  reg [7-1:0]   state = 0 ;     // should expose in module, not sure.

  reg [31:0]    clk_count_down;           // clk_count for the current phase. 31 bits is faster than 24 bits. weird. ??? 36MHz v 32MHz

  // reg [24-1:0]  clk_count_sample_n    = `CLK_FREQ / 100;   // 100nplc  10ms. + precharge
  reg [24-1:0]  clk_count_sample_n    = `CLK_FREQ / 10;   // == 0.1s  == 5 nplc .

  reg [24-1:0]  clk_count_precharge_n = `CLK_FREQ / 1000;   // 1ms



  // this would be an async signal???
  wire run = 1;

  always @(posedge clk  or posedge reset )
   if(reset)
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
        //////////////////
        // 1. switch precharge to boot voltage. (to protect signal)
        //
        // 2. switch AZ mux to signal.  (signal is protected by precharge).  AZ=SIG, PC=
        // 3. switch precharge  to signal.  and take sample.
        // 4. switch precharge to boot (to protect signal).
        // 5. switch AZ mux to zero - take sample.
        // 6  goto 2.

        // state vars are needed - because the actual zero used - will be encoded in a register.

        // sample period needs to be equal for both.

        0:
          // having a state like, this may be useful for debuggin, because can put a pulse on the monitor.
          state <= 1;

        // switch pc to boot to protect signal
        1:
          begin
            state           <= 15;
            clk_count_down  <= clk_count_precharge_n;
            sw_pc_ctl       <= `SW_PC_BOOT;
            //azmux          <= `MUX_ZERO;        // oesn't matter. but should leave defined?


            monitor         <= { 8 { 1'b0 } } ;     // reset
          end
        15:
          if(clk_count_down == 0)
            state <= 2;

        ////////////////////////////
        // loop. precharge_start
        // switch az mux to the PC OUT (signal is currently protected by pc)  - the 'precharge phase' or settle phase
        2:
            begin
              state           <= 25;
              clk_count_down  <= clk_count_precharge_n;
              azmux          <= `MUX_AZ_PC_OUT_PIN;      // pin s1
              // azmux          <= 4'b1000 ;
            end


        25:
          if(clk_count_down == 0)
            state <= 3;

        /////////////////////////
        // take the signal sample.   by switching pc to signal
        3:
          begin
            state           <= 35;
            clk_count_down  <= clk_count_sample_n;
            sw_pc_ctl       <= `SW_PC_SIGNAL;
            led0            <= 1;
            monitor[0]      <= 1;
          end
        35:
          if(clk_count_down == 0)
            state <= 4;

        // switch pc back to boot - to re-protect signal
        4:
          begin
            state           <= 45;
            clk_count_down  <= clk_count_precharge_n; // time less important here
            sw_pc_ctl       <= `SW_PC_BOOT;
          end
        45:
          if(clk_count_down == 0)
            state <= 5;

        /////////////////////////
        // take the zero - (signal is protected by pc
        5:
          begin
            state           <= 55;
            clk_count_down  <= clk_count_sample_n;
            azmux          <= az_mux_val;
            led0            <= 0;
            monitor[0]      <= 0;
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



