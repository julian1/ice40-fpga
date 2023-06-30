
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

`define STATE_RESET_START    0    // initial state
`define STATE_RESET          1
`define STATE_SIG_SETTLE_START 3
`define STATE_SIG_SETTLE    4
`define STATE_SIG_START     5


// implicit identifiers are only caught when modules have been instantiated
`default_nettype none



module modulation_mux (

  input   clk,


  input   reset,                    // async

  output  sig_pc_sw_ctl,

  output reg [7-1:0]   vec_monitor,

  // output reg mon1// , mon2, mon3, mon4, mon5, mon6, mon7,
  // output reg mon1

);

  // pack and unpack monitor header. should be register.

  reg [5-1:0]   state = `STATE_RESET_START;     // expose - not sure.

  // reg [31:0]  clk_count;           // clk_count for the current phase. 31 bits is faster than 24 bits. weird. ??? 36MHz v 32MHz
  reg [31:0]  clk_count_down;           // clk_count for the current phase. 31 bits is faster than 24 bits. weird. ??? 36MHz v 32MHz

  // input [24-1:0]  clk_count_reset_n,
  reg [24-1:0]  clk_count_reset_n = 10;
  reg [24-1:0]  clk_count_settle_n = 30;

  reg dummy;
  wire mon1, mon2 ;
  assign { mon2, mon1 ,  dummy } = vec_monitor ;


  always @(posedge clk  or posedge reset )

   if(reset)
    begin
      // set up next state, for when reset goes hi.
      state           <= `STATE_RESET_START;
    end
    else

    begin

      // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;


      case (state)

        // IMPORTANT. might can improved performance by reducing the reset and sig-settle times
        // reset time is also used for settle time.

        `STATE_RESET_START:
          begin
            state           <= `STATE_RESET;
            clk_count_down  <= clk_count_reset_n;

            sig_pc_sw_ctl   <= 1;
            mon1            <= 1;
            // mon2            <= 0;
          end

        `STATE_RESET:
          if(clk_count_down == 0)
            state <= `STATE_SIG_SETTLE_START;



        `STATE_SIG_SETTLE_START:
          begin
            state           <= `STATE_SIG_SETTLE;
            clk_count_down  <= clk_count_settle_n;

            sig_pc_sw_ctl   <= 0;
            mon1            <= 0;
            // mon2            <= 1;
          end


        `STATE_SIG_SETTLE:
          if(clk_count_down == 0)
            state <= `STATE_RESET_START;

      endcase


    end


endmodule



