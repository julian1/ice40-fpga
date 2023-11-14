
// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


// todo change name common. or macros. actually defines is ok.etc
`include "defines.v"




module sample_acquisition_no_az (

  input   clk,

  // inputs
  input adc_measure_valid,
  input arm_trigger,

  // wait phase.
  // reg [24-1:0]  p_clk_count_precharge = `CLK_FREQ * 500e-6 ;   // 500us.
  input [24-1:0] p_clk_count_precharge ,

  // outputs
  output reg adc_measure_trig,
  output reg led0,

  // now a wire.
  output wire [ 2-1:0]  monitor

);


  ////////////////
  reg [7-1:0]   state = 0 ;
  reg [31:0]    clk_count_down;



  reg [2-1: 0 ] arm_trigger_edge;  //  = "10";  // start off in state. so that arm works to halt.
                                    // doesn't work. should be in state 0. anyway.


  assign monitor[0] = adc_measure_trig;
  assign monitor[1] = adc_measure_valid;

  always @(posedge clk )

    begin


      // always decrement clk for the current phase
      // keeps setup condition simpler
      clk_count_down <= clk_count_down - 1;

      case (state)

        // precharge switch - protects the signal. from the charge-injection of the AZ switch.
        0:
          begin
            // having a state like, this may be useful for debuggin, because can put a pulse on the monitor.
            state <= 2;
            // state <= 40;   // start at park/done/ - then require a trigger - to start.

          end

        ////////////////////////////
        // keep a pause duration like a 'precharge' phase - to keep timing the same with az case.
        // TODO. to match - want a pasuse after the same also. when add to az.
        2:
            begin
              state           <= 25;
              clk_count_down  <= p_clk_count_precharge;  // normally pin s1

              // blink led, on alternate sampples, keeps visually identifiable at fast sample rates. and to match az-mode frequency.
              led0            <= led0  + 1;

            end
        25:
          if(clk_count_down == 0)
            state <= 3;

        /////////////////////////
        3:
          begin
            //state           <= 35;

            // trigger adc measure to do measure. interruptable at any time.
            adc_measure_trig    <= 1;

            // wait for adc to ack, before advancing
            if( ! adc_measure_valid )
              begin
                adc_measure_trig    <= 0;
                state             <= 35;
              end
          end

        35:
          begin
            // adc_measure_trig    <= 0;

            // wait for adc.
            if(  adc_measure_valid )
              state <= 2;


            // wait for adc.
            //if( ! adc_measure_trig &&  adc_measure_valid )
            //   state <= 2;
          end






        40: // done / park
          ;


      endcase

     /*
        // aquire.
      // run/pause, stop/go, reset,set etc.
      // edge triggered. so must perform in sequence
      // make sure fpga is in a default mode.

      // no transitions, this behavior should be transparent.
      // although we may want to start at the park condition.
        ---
        but we can toggle using a sequence - at mcu startup to select what we want.
        starting up in a default run state could be nice.
        and can be overriden by writting trigger, then arm.
      */


      arm_trigger_edge <= { arm_trigger_edge[0], arm_trigger};  // old, new

      if(arm_trigger_edge == 2'b01)        // trigger
        state <= 2;
      else if(arm_trigger_edge == 2'b10)   // park/arm/reset.
        state <= 40;



    end
endmodule


