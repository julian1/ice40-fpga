
/*
  - test / dummy  mocking adc.

  - adc is interruptable/ can be triggered to start at any time.
  - by by the az/non-az controller. so no handshake needed. so use _trig.
  - the adc when running is master/output channel. and therefore should assert valid when measurement is finished

*/

// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


module adc_mock (

  input   clk,
  input   reset_n,

  input [32-1:0]  p_clk_count_aperture_i,   // eg. clk_count_mux_sig_n

  // outputs
  output reg adc_measure_valid_o,     // adc is master, and asserts valid when measurement complete
  output wire [ 8-1:0]  monitor_o
);


  reg [7-1:0]   state = 0 ;
  reg [31:0]    clk_count_down;


  reg [ 6-1:0]  monitor; 

  // combinatorial logic
  assign monitor_o[0] = reset_n;
  assign monitor_o[1] = adc_measure_valid_o;
  assign monitor_o[2 +: 6 ] = monitor;




  always @(posedge clk   )
    begin

      // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;

      case (state)

        0:
          // reset state.
          begin

            // setup next state to advance to if reset_n not asserted
            state <= 1;

            // indicate no measurement available
            adc_measure_valid_o <= 0;


            // set sample/measure period
            clk_count_down  <= p_clk_count_aperture_i;

            monitor <= 6'b0;
          end


        1:
          begin
            // mock/sim measurement - by waiting for measurement
            if(clk_count_down == 0)
              state <= 4;
          end

        4:
          // measure done
          begin
            // assert the measurement is done/valid
            adc_measure_valid_o <= 1;

          end
      endcase


      // override all states - if reset_n enabled, then don't advance out-of reset state.
      if(reset_n == 0)      // in reset
        begin

            state <= 0;
        end


    end
endmodule





