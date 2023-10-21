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



module modulation_az (

  // remember hi mux is not manipulated, or passed into this module.
  // inistead the hi signal is seleced by the AZ mux, via the pre-charge switch

  input   clk,
  input   reset,

  // lo mux input to use.
  input [  4-1 : 0 ] azmux_lo_val,

  // measure done
  input adc_take_measure_done,

  // outputs.
  output reg adc_take_measure,

  output reg  sw_pc_ctl,
  output reg [ 4-1:0 ] azmux,

  output reg led0,
  output reg [ 2-1:0]  monitor,
);

  reg [7-1:0]   state = 0 ;     // should expose in module, not sure.

  reg [31:0]    clk_count_down;           // clk_count for the current phase. using 31 bitss, gives faster timing spec.  v 24 bits. weird. ??? 36MHz v 32MHz


  // change name clk_precharge_duration_n
  reg [24-1:0]  clk_count_precharge_n = `CLK_FREQ * 500e-6 ;   // 500us.
  // reg [24-1:0]  clk_count_precharge_n = `CLK_FREQ * 5e-3 ;         // 5ms


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
            sw_pc_ctl       <= `SW_PC_BOOT;
            // azmux           <=  azmux_lo_val;       // should be defined. or set in async reset. not left over state.
            monitor         <= { 2 { 1'b0 } } ;     // reset


            adc_take_measure    <= 0;
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
              // azmux          <= azmux_hi_val;
              azmux             <= `AZMUX_HI_VAL;

              monitor[0]      <= 1;
            end
        25:
          if(clk_count_down == 0)
            state <= 3;


        /////////////////////////
        // switch pc-switch from BOOT to signal. take hi measure
        3:
          begin
            state           <= 35;
            // clk_count_down  <= clk_sample_duration;
            sw_pc_ctl       <= `SW_PC_SIGNAL;
            led0            <= 1;
            monitor[1]      <= 1;

            // must be a better name. trigger. rdy. do.
            adc_take_measure    <= 1;
          end
        35:
          // wait for adc.
          if(adc_take_measure_done == 1)
            state <= 4;


        // switch pre-charge switch back to boot to protect signal again
        4:
          begin
            state           <= 45;
            clk_count_down  <= clk_count_precharge_n; // time less important here
            sw_pc_ctl       <= `SW_PC_BOOT;
            monitor[1]      <= 0;
          end
        45:
          if(clk_count_down == 0)
            state <= 5;

        /////////////////////////
        // switch az mux to lo.   take lo measurement
        5:
          begin
            state           <= 55;
            // clk_count_down  <= clk_sample_duration;
            azmux           <= azmux_lo_val;
            led0            <= 0;
            monitor[0]      <= 0;

            // must be a better name. trigger. rdy. do.
            adc_take_measure    <= 1;
          end

        55:
          // wait for adc.
          if(adc_take_measure_done == 1)
            state <= 6;


        6:
          if(run )        // place at end.
            state <= 2;


      endcase
    end
endmodule




module adc (

  input   clk,
  input   reset,
  input [ 32-1 : 0 ] clk_sample_duration,  // 32/31 bit nice. for long sample....  wrongly named it is counter_sample_duration. not clk...
  input adc_take_measure,  // wire

  output reg adc_take_measure_done

);

  reg [7-1:0]   state = 0 ;
  reg [31:0]    clk_count_down;


  always @(posedge clk  or posedge reset )
   if(reset)
    begin
      // set up next state, for when reset goes hi.
      state           <= 0;

      adc_take_measure_done <= 0;
    end
    else
    begin

      // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;


      case (state)

        0:
          // having a state like, this may be useful for debuggin, because can put a pulse on the monitor.
          state <= 2;

        /////////////////////////

        2:
          // wait for trigger that are ready to do the adc
          if(adc_take_measure == 1)
            state <= 3;

        3:
          // set up state for measurement
          begin
            state           <= 35;
            clk_count_down  <= clk_sample_duration;
          end

        35:
          // wait for measurement to complete
          if(clk_count_down == 0)
            state <= 4;

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







