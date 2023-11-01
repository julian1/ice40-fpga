/*

  normal az

*/


// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


// note. counter freq is half clk, because increments on clk.
`define CLK_FREQ        20000000



////////////////////


`define SW_PC_SIGNAL    1
`define SW_PC_BOOT      0


// AZMUX PC-OUT select the hi
`define S1              ((1<<3)|(1-1))
`define AZMUX_HI_VAL    `S1     // PC-OUT



module sample_acquisition_az (

  // remember hi mux is not manipulated, or passed into this module.
  // inistead the hi signal is seleced by the AZ mux, via the pre-charge switch

  // inputs
  input   clk,
  // input   reset,
  input [ 4-1 : 0 ] azmux_lo_val,
  input adc_measure_valid,

  // outputs.
  output reg adc_measure_trig,
  output reg  sw_pc_ctl,
  output reg [ 4-1:0 ] azmux,
  output reg led0,

  // output reg [ 2-1:0]  monitor,     // but it suppresses the warning.

  // now a wire.
  output wire [ 2-1:0]  monitor       // 
);

  reg [7-1:0]   state = 0 ;     // should expose in module, not sure.

  reg [31:0]    clk_count_down;           // clk_count for the current phase. using 31 bitss, gives faster timing spec.  v 24 bits. weird. ??? 36MHz v 32MHz


  // change name clk_precharge_duration_n
  reg [24-1:0]  clk_count_precharge_n = `CLK_FREQ * 500e-6 ;   // 500us.


  reg [ 4-1:0]  monitor_; 

  assign monitor[0] = adc_measure_trig;
  assign monitor[1] = adc_measure_valid;





  always @(posedge clk  /*or posedge reset */ )
/*
   if(reset)
    begin
      // we only require to set the state here, to setup the initial conditions.
      state           <= 0;
    end
    else
*/
    begin

      // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;


      case (state)

        // precharge switch - protects the signal. from the charge-injection of the AZ switch.
        0:
          begin
            // having a state like, this may be useful for debuggin, because can put a pulse on the monitor.
            state <= 1;

            adc_measure_trig    <= 0;

            // monitor         <= { 2 { 1'b0 }   } ;
          end

        // switch pre-charge switch to boot to protect signal
        1:
          begin
            state           <= 15;
            clk_count_down  <= clk_count_precharge_n;
            sw_pc_ctl       <= `SW_PC_BOOT;
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
              azmux             <= `AZMUX_HI_VAL;
            end
        25:
          if(clk_count_down == 0)
            state <= 3;


        /////////////////////////
        // switch pc-switch from BOOT to signal. and tell adc to take measurement
        // TODO - maybe add small settle time. after switching the pc switch ..
        // not sure.
        3:
          begin
            state           <= 35;
            sw_pc_ctl       <= `SW_PC_SIGNAL;
            led0            <= 1;

            // tell the adc to start.  adc is always interruptable
            adc_measure_trig <= 1;
            // monitor[1]      <= 1;
          end

        35:
          begin
            //
            adc_measure_trig <= 0;
            // monitor[1]      <= 0;

            /* block for adc complete
              We could elevate this outside a case statement
              */

            if( ! adc_measure_trig &&  adc_measure_valid )
              state <= 4;
          end


        //////////////////////////////

        // switch pre-charge switch back to boot to protect signal again
        4:
          begin
            state           <= 45;
            clk_count_down  <= clk_count_precharge_n; // time less important here
            sw_pc_ctl       <= `SW_PC_BOOT;
          end
        45:
          if(clk_count_down == 0)
            state <= 5;

        /////////////////////////
        // switch az mux to lo.   take lo measurement
        // TODO - need to provide a settle time. after switching lo..
        5:
          begin
            state           <= 55;
            azmux           <= azmux_lo_val;
            led0            <= 0;

            // tell the adc to start.  adc is always interruptable
            adc_measure_trig <= 1;
            // monitor[1]      <= 1;
          end

        55:
          begin
            adc_measure_trig <= 0;
            // monitor[1]      <= 0;


            /* block for adc complete
              We could elevate this outside a case statement
              */

            if( ! adc_measure_trig &&  adc_measure_valid )
              // restart sequence
              state <= 2;

          end



      endcase
    end
endmodule




