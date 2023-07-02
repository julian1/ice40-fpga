/*

  we have the two clk transitions. but it makes it clearer to read.


  TODO - change name 'zero' -> 'lo'.  not sure.

  TODO - change 'active'   to 'mode'

          eg. normal AZ. where we switch between SIG/ZERO

*/


// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


`define CLK_FREQ        20000000

`define MUX_AZ_PC_OUT   (0 )      // mux precharge output, or a zero.   s1 == PC-OUT == SIGNAL
`define MUX_AZ_ZERO     (8 - 1)   // s8 == 4.7k to star-ground.  change to value in a register .   all the LO they are all ZEROcall it ZER

`define SW_PC_SIGNAL    1
`define SW_PC_BOOT      0



`define AZ_MODE_AZ_NORMAL   1
`define AZ_MODE_SIGNAL_HI   2
`define AZ_MODE_LO          3


module modulation_az (

  input   clk,
  input   reset,                    // async

  input   [7-1: 0 ] mode,

  // input   use_precharge,         // for comparison

  output reg  sw_pc_ctl,
  output reg [  3-1 : 0 ] mux_az ,       // going to be driven -  so should  be a register


  output reg [7-1:0]   vec_monitor,

  // output reg mon1// , mon2, mon3, mon4, mon5, mon6, mon7,
  // output reg mon1

);

  // localparam x = 1;


  // pack and unpack monitor header. should be register.

  reg [7-1:0]   state = 0 ;     // should expose in module, not sure.

  reg [31:0]    clk_count_down;           // clk_count for the current phase. 31 bits is faster than 24 bits. weird. ??? 36MHz v 32MHz

  reg [24-1:0]  clk_count_sample_n    = `CLK_FREQ / 100;   // 100nplc  10ms.

  reg [24-1:0]  clk_count_precharge_n = `CLK_FREQ / 1000;   // 1ms


  reg dummy ;
  assign vec_monitor = { mux_az , sw_pc_ctl, dummy} ; // nice

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
            //mux_az          <= `MUX_ZERO;        // doesn't matter. but leave defined.
          end
        15:
          if(clk_count_down == 0)
            state <= 2;

        ////////////////////////////
        // loop. precharge_start
        // switch az mux to signal/pc output (signal is protected by pc)  - the 'precharge phase' or settle phase
        2:
          case (mode)
            `AZ_MODE_AZ_NORMAL:  //   normal AZ/precharge mode cycle
              begin
                state           <= 25;
                clk_count_down  <= clk_count_precharge_n;
                mux_az          <= `MUX_AZ_PC_OUT;          // select signal
              end

            `AZ_MODE_SIGNAL_HI:        // hold and follow the output from the himux
              begin
                sw_pc_ctl       <= `SW_PC_SIGNAL;
                mux_az          <= `MUX_AZ_PC_OUT;
              end

            `AZ_MODE_LO:       // hold lo, which lo should be read from the register.
              begin
                sw_pc_ctl       <= `SW_PC_BOOT;   // park at boot. doesn't really matter.
                mux_az          <= `MUX_AZ_ZERO;
              end

            default:  // should be error condition .
              mux_az          <= `MUX_AZ_PC_OUT;    
              // this is

          endcase

        25:
          if(clk_count_down == 0)
            state <= 3;

        /////////////////////////
        // switch pc to signal - take signal sample .   sample_phase_start.
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
            state <= 6;


        6:
          if(run )        // place at end.
            state <= 2;


      endcase


    end


endmodule



