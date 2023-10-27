
// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


// note. counter freq is half clk, because increments on clk.
`define CLK_FREQ        20000000



////////////////////

// TODO move these to common file.

// TODO - add these in mcu code also.  it gets too confusing otherwise.
`define SW_PC_SIGNAL    1
`define SW_PC_BOOT      0


`define S1              ((1<<3)|(1-1))
// `define S2          ((1<<3)|(2-1))





module modulation_no_az (

  // inputs
  input   clk,
  input   reset,
  input adc_measure_valid,

  
  // output
  // regs/state
  output reg adc_measure_trig,
  output reg led0,
  output reg [ 2-1:0]  monitor,     // but it suppresses the warning.
);


  ////////////////
  reg [7-1:0]   state = 0 ;     // should expose in module, not sure.
  reg [31:0]    clk_count_down;           // clk_count for the current phase. using 31 bitss, gives faster timing spec.  v 24 bits. weird. ??? 36MHz v 32MHz

  // wait phase.
  reg [24-1:0]  clk_count_precharge_n = `CLK_FREQ * 500e-6 ;   // 500us.




  always @(posedge clk  or posedge reset )
   if(reset)
    begin
      // we only require to set the state here, to setup the initial conditions.
      state           <= 0;
    end
    else
    begin

      // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;

      case (state)

        // precharge switch - protects the signal. from the charge-injection of the AZ switch.
        0:
          begin
            // having a state like, this may be useful for debuggin, because can put a pulse on the monitor.
            state <= 2;

            monitor = 2'b00;

          end

        ////////////////////////////
        // keep a pause duration like a 'precharge' phase - to keep timing the same with az case.
        // TODO. to match - want a pasuse after the same also. when add to az.
        2:
            begin
              state           <= 25;
              clk_count_down  <= clk_count_precharge_n;  // normally pin s1

              // blink led, on alternate sampples, keeps visually identifiable at fast sample rates. and to match az-mode frequency.
              led0    <= led0  + 1;

            end
        25:
          if(clk_count_down == 0)
            state <= 3;

        /////////////////////////
        3:
          begin
            state           <= 35;

            // tell adc to do measure. interuptable at any time.
            adc_measure_trig    <= 1;
            monitor[1]      <= 1;
          end

        35:
          begin
            adc_measure_trig    <= 0;
            monitor[1]          <= 0;

            // wait for adc.
            if( ! adc_measure_trig &&  adc_measure_valid )
              state <= 2;
          end


      endcase
    end
endmodule




/*

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
          0:
          // having a state like, this may be useful for debuggin, because can put a pulse on the monitor.
          state <= 1;

        // switch pre-charge switch to boot to protect signal
        1:
          begin
            state           <= 15;
            clk_count_down  <= clk_count_precharge_n;
            // sw_pc_ctl       <= `SW_PC_BOOT;
            // azmux           <=  azmux_lo_val;       // should be defined. or set in async reset. not left over state.
            // monitor         <= { 8 { 1'b0 } } ;     // reset
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
              clk_count_down  <= clk_count_precharge_n;  // normally pin s1
              // azmux          <= `AZMUX_HI_VAL;
              // monitor[0]      <= 1;
            end
        25:
          if(clk_count_down == 0)
            state <= 3;


        /////////////////////////
        // switch pc-switch from BOOT to signal. take hi measure
        3:
          begin
            state           <= 35;
            clk_count_down  <= clk_sample_duration;
            // sw_pc_ctl       <= `SW_PC_SIGNAL;
            // led0            <= 1;
            // monitor[1]      <= 1;
          end
        35:
          if(clk_count_down == 0)
            state <= 4;

        // switch pre-charge switch back to boot to protect signal again
        4:
          begin
            state           <= 45;
            clk_count_down  <= clk_count_precharge_n; // time less important here
            // sw_pc_ctl       <= `SW_PC_BOOT;
            // monitor[1]      <= 0;
          end
        45:
          if(clk_count_down == 0)
            state <= 5;

        /////////////////////////
        // switch az mux to lo.   take lo measurement
        5:
          begin
            state           <= 55;
            clk_count_down  <= clk_sample_duration;
            // azmux           <= azmux_lo_val;
            // led0            <= 0;
            // monitor[0]      <= 0;
          end
        55:
          if(clk_count_down == 0)
            state <= 6;


        6:
          if(run )        // place at end.
            state <= 2;
*/


