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

  // inputs
  input   clk,
  input   reset,
  input [ 32-1 : 0 ] clk_sample_duration,  // 32/31 bit nice. for long sample....  wrongly named it is counter_sample_duration. not clk...
  input adc_measure_start,  // wire




  output reg [ 2-1:0]  refmux,     // reference current, better name? 
  output reg sigmux,
  output reg resetmux,             // ang mux.


  // outputs
  output reg adc_measure_done,
  // output reg [ 4-1:0 ] adcmux,
  output reg  cmpr_latch,

  // OK. we may want to remove
  output reg [ 6-1:0]  monitor
);

  reg [7-1:0]   state = 0 ;
  reg [31:0]    clk_count_down;

/*
  actually it might make sense to intercept the signal.
  and only have 5.

  -----
  - EXTR. monitor[0] should be given the adc_measure_start signal.
    as the initial triggering condition.
  - also we may want to wait a bit.
    but that should probably be done in the az mode.
  - also want to probably pass a stamp or code. as to what we sampled.
      NO. that is for the sample controller.
      EXTR. sample controller can just write a reg. depending on if sample is the HI. or the LO.

*/

  always @(posedge clk  or posedge reset )
   if(reset)
    begin
      // set up next state, for when reset goes hi.
      state           <= 0;

      adc_measure_done <= 1;

      monitor         <= { 6 { 1'b0 } } ;     // reset
      // adcmux          <= { 4 { 1'b0 } } ;     // reset
      cmpr_latch      <= 0;
      ////////////////

      refmux = 2'b00;
      sigmux = 1'b0;
      resetmux = 1'b0;

    end
    else
    begin

      // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;

 
      // trigger off the start signal. 
      // just about want wire this in the top level module..
      monitor[0] =  adc_measure_start;


      case (state)

        0:
          begin
          // having a state like, this may be useful for debuggin, because can put a pulse on the monitor.
            state <= 2;

            adc_measure_done <= 1;

          end
        /////////////////////////

        2:
          // block for start trigger that are ready for sample
          if(adc_measure_start == 1)
              state <= 3;


        3:
          // set up state for measurement
          begin
            adc_measure_done <= 0;
            state           <= 35;
            clk_count_down  <= clk_sample_duration;
          end

        35:
          begin


            // wait for measurement to complete
            if(clk_count_down == 0)
              state <= 4;
          end

        4:
          // measure done
          begin
            state           <= 5;
            // signal measurement done
            adc_measure_done <= 1;

          end

        5:
          begin
            state           <= 2;
            // clear measurement done
            adc_measure_done <= 0;
          end



      endcase
    end
endmodule







