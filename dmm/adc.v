
/*

  - adc is interuptable/ can be triggered to start at any time.
  - by by the az/non-az controller. so no handshake needed. so use _trig.
  - the adc when running is master/output channel. and therefore should assert valid when measurement is finished


*/

// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


module adc (

  // inputs
  input   clk,
  input   reset,
  input [ 32-1 : 0 ] clk_sample_duration,  // 32/31 bit nice. for long sample....  wrongly named it is counter_sample_duration. not clk...
  input adc_measure_trig,  // wire




  output reg [ 2-1:0]  refmux,     // reference current, better name?
  output reg sigmux,
  output reg resetmux,             // ang mux.


  // outputs
  output reg adc_measure_valid,     // adc is master, and asserts valid when ready to transfer control or data
  // output reg [ 4-1:0 ] adcmux,
  output reg  cmpr_latch,

  // OK. we may want to remove
  output reg [ 6-1:0]  monitor
);

  reg [7-1:0]   state = 0 ;
  reg [31:0]    clk_count_down;



  always @(posedge clk  or posedge reset )
   if(reset)
      begin

        // we only require to set the state here, to setup the initial conditions.
        state           <= 0;

      end
    else
      begin


        // monitor[0] follows the start trigger
        // just should just about be a wire - combinatorial at the
        monitor[0] <=  adc_measure_trig;
        monitor[1] <=  adc_measure_valid;



      /////////////////

        // refmux <= refmux + 1;
        // sigmux <= sigmux + 1;
        resetmux <= resetmux + 1;

        // always decrement clk for the current phase
        clk_count_down <= clk_count_down - 1;

        case (state)

          0:
              // just jump to end, to indicate valid
              state <= 4;

          35:
            begin
              // wait for measurement to complete
              if(clk_count_down == 0)
                state <= 4;
            end

          4:
            // measure done
            begin
              // assert done/valid
              adc_measure_valid <= 1;

            end
        endcase



        // adc is interuptable/ can be triggered to start at any time.
        if(adc_measure_trig == 1)
          begin

              state <= 35;

              // adc is master.
              adc_measure_valid <= 0;

              // don't clear. makes it hard to tell
              monitor[6-1: 1  ]  <= { 4 { 1'b0 } } ;     // clear

              ////////////////
              cmpr_latch      <= 0;
              refmux = 2'b00;
              sigmux = 1'b0;
              resetmux = 1'b0;

              // set sample/measure period
              clk_count_down  <= clk_sample_duration;

          end


      end
endmodule






/*
  actually it might make sense to intercept the signal.
  and only have 5.

  -----
  - EXTR. monitor[0] should be given the adc_measure_trig signal.
    as the initial triggering condition.
  - also we may want to wait a bit.
    but that should probably be done in the az mode.
  - also want to probably pass a stamp or code. as to what we sampled.
      NO. that is for the sample controller.
      EXTR. sample controller can just write a reg. depending on if sample is the HI. or the LO.

*/
