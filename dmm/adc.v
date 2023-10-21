/*

    Use _start  to prefix. and perhaps _done.
    adc_measure_start
    adc_measure_done
    --------

      - EXTR. OR DON"T MUX.

    - insteda adc - can monitor any of the adc controllers.

  - OR. just use OR - for the three controller signals.
      So any controller can initiate the adc start.

    - and then make sure only one az controller is ever active.  (maybe even using reset).

    -------
    - the muxer provides nice decoupling / isolation.
    ------------

    - OR the muxer itself -

    -------
  ===============
    - EXTR. or the adc should start with adc_measure done = 1.   so the az controller is never blocked.

        And the adc only clears  it when it gets the start.

        Also perhaps pad a few clock cycles - in the az controller - to let the adc clear the done flag.
  ===============

        YES. this ought to eliminate the need for reset.


*/

// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


module adc (

  input   clk,
  input   reset,
  input [ 32-1 : 0 ] clk_sample_duration,  // 32/31 bit nice. for long sample....  wrongly named it is counter_sample_duration. not clk...
  input adc_take_measure,  // wire

  // outputs
  output reg adc_take_measure_done,

  output reg [ 8-1:0]  monitor   // there is no reason to prematurely narrow the monitor here. can be done at top level.
);

  reg [7-1:0]   state = 0 ;
  reg [31:0]    clk_count_down;

/*
  actually it might make sense to intercept the signal.
  and only have 5.

  -----
  - EXTR. monitor[0] should be given the adc_take_measure signal.
    as the initial triggering condition.
  - also we may want to wait a bit.
    but that should probably be done in the az mode.
  - also want to probably pass a stamp or code. as to what we sampled.

*/

  always @(posedge clk  or posedge reset )
   if(reset)
    begin
      // set up next state, for when reset goes hi.
      state           <= 0;

      adc_take_measure_done <= 1;

      monitor         <= { 8 { 1'b0 } } ;     // reset
    end
    else
    begin

      // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;


      case (state)

        0:
          begin
          // having a state like, this may be useful for debuggin, because can put a pulse on the monitor.
            state <= 2;

            adc_take_measure_done <= 1;

            monitor[0]      <= 0;           // turn monitor on.
          end
        /////////////////////////

        2:
          // wait for trigger that are ready to do the adc
          if(adc_take_measure == 1)
              state <= 3;


        3:
          // set up state for measurement
          begin
            adc_take_measure_done <= 0;
            state           <= 35;
            clk_count_down  <= clk_sample_duration;
            monitor[0]      <= 1;
          end

        35:
          begin

            monitor[0]      <= 0;

            // wait for measurement to complete
            if(clk_count_down == 0)
              state <= 4;
          end

        4:
          // measure done
          begin
            state           <= 5;
            // signal measurement done
            adc_take_measure_done <= 1;

          end

        5:
          begin
            state           <= 2;
            // clear measurement done
            adc_take_measure_done <= 0;
          end



      endcase
    end
endmodule







