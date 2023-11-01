
/*
  - test / dummy  mocking adc.

  - adc is interruptable/ can be triggered to start at any time.
  - by by the az/non-az controller. so no handshake needed. so use _trig.
  - the adc when running is master/output channel. and therefore should assert valid when measurement is finished


*/

// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


module adc_test (

  input   clk,

  // inputs
  input [ 32-1 : 0 ] clk_sample_duration,  // 32/31 bit nice. for long sample....  wrongly named it is counter_sample_duration. not clk...
  input adc_measure_trig,         // wire. start measurement.

  // outputs
  output reg adc_measure_valid,     // adc is master, and asserts valid when measurement complete
  output wire [ 6-1:0]  monitor
);


  reg [7-1:0]   state = 0 ;
  reg [31:0]    clk_count_down;


  reg [ 4-1:0]  monitor_; 

  assign monitor[0] = adc_measure_trig;
  assign monitor[1] = adc_measure_valid;
  assign monitor[2 +: 4 ] = monitor_;




  always @(posedge clk   )
    begin

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


            // set sample/measure period
            clk_count_down  <= clk_sample_duration;

            monitor_ <= 4'b0;

            // monitor     <=  6'b000000; 


        end


    end
endmodule





