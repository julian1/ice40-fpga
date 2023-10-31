
/*

  - adc is interruptable/ can be triggered to start at any time.
  - by by the az/non-az controller. so no handshake needed. so use _trig.
  - the adc when running is master/output channel. and therefore should assert valid when measurement is finished


*/

// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


module adc_test (

  // inputs
  input   clk,
  input   reset,                // TODO remove. should always be interruptable.
  input [ 32-1 : 0 ] clk_sample_duration,  // 32/31 bit nice. for long sample....  wrongly named it is counter_sample_duration. not clk...
  input adc_measure_trig,         // wire. start measurement.


  // outputs
  output reg  cmpr_latch,
  output reg [ 2-1:0]  refmux,     // reference current, better name?
  output reg sigmux,
  output reg resetmux,             // ang mux.

  output reg adc_measure_valid,     // adc is master, and asserts valid when measurement complete

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


        // delayed by a clock cycle
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



        // adc is interruptable/ can be triggered to start at any time.
        if(adc_measure_trig == 1)
          begin

              state <= 35;

              // adc is master.
              adc_measure_valid <= 0;

              ////////////////
              cmpr_latch      <= 0;
              refmux = 2'b00;
              sigmux = 1'b0;
              resetmux = 1'b0;

              // set sample/measure period
              clk_count_down  <= clk_sample_duration;


              // monitor     <=  6'b000000; 


          end


      end
endmodule





