
// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


// todo change name common. or macros. actually defines is ok.etc
`include "defines.v"




module sample_acquisition_no_az (

  input   clk,
  input   reset_n,

  // inputs
  input adc_measure_valid,

  // wait phase.
  input [24-1:0] p_clk_count_precharge ,

  // outputs
  output reg adc_reset_no,
  output reg led0,

  // now a wire.
  output wire [ 8-1:0]  monitor

);


  ////////////////
  reg [7-1:0]   state = 0 ;
  reg [31:0]    clk_count_down;


/*
  reg [2-1: 0 ] arm_trigger_edge;  //  = "10";  // start off in state. so that arm works to halt.
                                    // doesn't work. should be in state 0. anyway.
*/

  assign monitor[0] = adc_reset_no;
  assign monitor[1] = adc_measure_valid;
  assign monitor[2 +: 6 ] = 0;

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

            adc_reset_no    <= 0;

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
            begin
              state <= 35;

              // trigger adc measure to do measure. interruptable at any time.
              adc_reset_no    <= 1;
            end

/*
        /////////////////////////
        3:
          // wait for adc to ack trig, before advancing
          if( ! adc_measure_valid )
            begin
              adc_reset_no    <= 0;
              state             <= 35;
            end
*/

        35:
          // wait for adc.
          if(  adc_measure_valid )
            begin

              // restart sequence
              state <= 2;

              // set status for lo sample. set after measure to give time to read.
              // status_o      <= 3'b000;

              // JA added. put adc in reset again
              adc_reset_no <= 0;

            end

      endcase



      // override all states - if reset_n enabled, then don't advance out-of reset state.
      if(reset_n == 0)      // in reset
        begin

            state <= 0;
        end

    end
endmodule




