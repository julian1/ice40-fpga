/*

  we have the two clk transitions. but it makes it clearer to read.


  TODO - change name 'zero' -> 'lo'.  not sure.

  TODO - change 'active'   to 'mode'

          eg. normal AZ. where we switch between SIG/ZERO

*/


// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


`define CLK_FREQ        20000000
// note. that counter freq is half clk, because increments on clk.



////////////////////

// TODO this value needs the EN pin set.

// `define MUX_AZ_PC_OUT_PIN   4'b1000   // AZ switch pin muxes pc-out.

`define SW_PC_SIGNAL    1
`define SW_PC_BOOT      0






module modulation_az (

  // remember hi mux is not manipulated, or passed into this module.
  // inistead the hi signal is seleced by the AZ mux, via the pre-charge switch

  input   clk,
  input   reset,

  // lo mux input to use.
  input [  4-1 : 0 ] azmux_lo_val,
  input [  4-1 : 0 ] azmux_hi_val,  // should almost always be S1 == 4'b1000 , for pc-out. except when off, or 4 cycle measurement.

  /// outputs.
  output reg  sw_pc_ctl,
  output reg [ 4-1:0 ] azmux ,       // change name   az lo value.

  output reg led0,
  output reg [ 8-1:0]  monitor,

);

  reg [7-1:0]   state = 0 ;     // should expose in module, not sure.

  reg [31:0]    clk_count_down;           // clk_count for the current phase. using 31 bitss, gives faster timing spec.  v 24 bits. weird. ??? 36MHz v 32MHz


  // these registers need to be controllable, to run switch pre-charge switch fast.
  // OK. but perhaps want to be written as a single bitvector again. for ease.

  // want to be able to do a sample for 1s. or longer .
  // REG_CLK_COUNT_SAMPLE_N

  // remember counter is already divided by 2. from the 20MHz to 10Mhz..
  // reg [24-1:0]  clk_count_sample_n    = `CLK_FREQ / 50 * 10 ;    // 10nplc.  200ms. for both signal, and zero.
  reg [24-1:0]  clk_count_sample_n    = `CLK_FREQ / 50 ;            // 1nplc.   20ms. for both signal, and zero.

  reg [24-1:0]  clk_count_precharge_n = `CLK_FREQ / 2 / 1000;   // 500us.



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
        // loop. azmux to the output of the precharge  switch
        // switch azmux to PC OUT.    (signal is currently protected by pc)  - the 'precharge phase' or settle phase
        2:
            begin
              state           <= 25;
              clk_count_down  <= clk_count_precharge_n;  // normally pin s1
              azmux          <=   azmux_hi_val;
              monitor[0]      <= 1;
            end
        25:
          if(clk_count_down == 0)
            state <= 3;


        /////////////////////////
        // PC SW manipulation.
        // The trick is that the PC switching runs inside the AZ switch in the time dimension.
        // expose/take the raw signal sample.   by switching pc_sw to signal
        3:
          begin
            state           <= 35;
            clk_count_down  <= clk_count_sample_n;
            sw_pc_ctl       <= `SW_PC_SIGNAL;
            led0            <= 1;
            monitor[1]      <= 1;
          end
        35:
          if(clk_count_down == 0)
            state <= 4;

        // re-protect signal. by switching pc_sw back to boot
        4:
          begin
            state           <= 45;
            clk_count_down  <= clk_count_precharge_n; // time less important here
            sw_pc_ctl       <= `SW_PC_BOOT;
            monitor[1]      <= 0;
          end
        45:
          if(clk_count_down == 0)
            state <= 5;

        /////////////////////////
        // take the zero - by switching az mux.
        5:
          begin
            state           <= 55;
            clk_count_down  <= clk_count_sample_n;
            azmux           <= azmux_lo_val;
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



