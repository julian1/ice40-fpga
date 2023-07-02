
/*
  - remove the double clk count state switching that we have. with start labels.
  - if a state is reached from more than one other state
        - then use a function. to avoid repeating set setting of the conditions.

    - it is clearer, in reducing the number of state elements.
  ----------

  alternatively do a test of the clk count.
  if clk_count == 0
    thne do state initialization.
    No. - because this creates a two-clock transition

  -----------------------

  if implemented a count-down clock, instead of count-up.  then we can test against 0 which is quite a bit clearer.
      don't have the target phase time - in the setup for the state.


*/


// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


/*
`define STATE_RESET_START    0    // initial state
`define STATE_RESET          1
`define STATE_SIG_SETTLE_START 3
`define STATE_SIG_SETTLE    4
`define STATE_SIG_START     5

// we have to have start
`define STATE_AZ_SIGNAL           6
`define STATE_AZ_SIGNAL_START     7
`define STATE_AZ_ZERO             8
`define STATE_AZ_ZERO_START       7
`define STATE_PC_BOOT             8
`define STATE_PC_BOOT_START       9
`define STATE_PC_SIGNAL           10
`define STATE_PC_SIGNAL_START     11

*/
        // state_AZ_signal. state_AZ_zero
        // state_precharge_boot, state_precharge_signal.


`define MUX_AZ_PC_OUT   (0 )  // s1 == PC-OUT
`define MUX_AZ_ZERO     (8 - 1)  // s8 == 4.7k to star-ground

`define SW_PC_SIGNAL    1
`define SW_PC_BOOT      0


module modulation_az (

  input   clk,
  input   reset,                    // async

  // input   use_precharge,         // for comparison

  output reg  sw_pc_ctl,
  output reg [  3-1 : 0 ] mux_az ,       // going to be driven -  so should  be a register


  output reg [7-1:0]   vec_monitor,

  // output reg mon1// , mon2, mon3, mon4, mon5, mon6, mon7,
  // output reg mon1

);

  // localparam x = 1;


  // pack and unpack monitor header. should be register.

  reg [7-1:0]   state = 0 ;     // expose - not sure.

  reg [31:0]  clk_count_down;           // clk_count for the current phase. 31 bits is faster than 24 bits. weird. ??? 36MHz v 32MHz

  reg [24-1:0]  clk_count_sample_n  = 20000000 / 100;   // 100nplc  10ms.

  reg [24-1:0]  clk_count_precharge_n  = 20000000 / 1000;   // 1ms


  reg dummy ;
  assign vec_monitor = { mux_az , sw_pc_ctl, dummy} ; // nice


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
        // 1. switch precharge to boot voltage. // == first.
        //
        // 2. switch AZ mux to signal.  (signal is protected by precharge).  AZ=SIG, PC=
        // 3. switch precharge  to signal.  and take sample.
        // 4. switch precharge to boot.
        // 5. switch AZ mux to zero - take sample.
        // 6  goto 2.

        // state vars are needed - because the actual zero used - will be encoded in a register.

        // sample period needs to be equal for both.

        0:
          state <= 1;

        // switch pc to boot to protect signal
        1:
          begin
            state           <= 15;
            clk_count_down  <= 20000000 / 1000;
            sw_pc_ctl       <= `SW_PC_BOOT;
            // mux_az          <= `MUX_ZERO;        // doesn't matter.
          end
        15:
          if(clk_count_down == 0)
            state <= 2;

        ////////////////////////////
        // loop.
        // switch az mux to signal/pc output (signal is protected by pc)  - the 'precharge phase' or settle phase
        2:
          begin
            state           <= 25;
            clk_count_down  <= clk_count_precharge_n; // 1ms clk_count_sample_n;
            mux_az          <= `MUX_AZ_PC_OUT;
          end
        25:
          if(clk_count_down == 0)
            state <= 3;

        /////////////////////////
        // switch pc to signal - take signal sample
        3:
          begin
            state           <= 35;
            clk_count_down  <= clk_count_sample_n;
            sw_pc_ctl       <= `SW_PC_SIGNAL;
          end
        35:
          if(clk_count_down == 0)
            state <= 4;

        // switch pc to boot - to re-protect signal
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
        // switch mux to zero (signal is protected by pc) - take zero sample - zero psample phase. (do we want a pause here?)
        5:
          begin
            state           <= 55;
            clk_count_down  <= clk_count_sample_n;
            mux_az          <= `MUX_AZ_ZERO;
          end
        55:
          if(clk_count_down == 0)
            state <= 2;



      endcase


    end


endmodule



