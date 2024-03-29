/*

  normal az

*/


// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


// todo change name common. or macros. actually defines is ok.etc
`include "defines.v"



// `define AZMUX_PCOUT    `S3     // 2024.  FIXME



module sample_acquisition_az (

  // remember hi mux is not manipulated, or given to this module.
  // inistead the hi signal is seleced by the AZ mux, via the pre-charge switch

  input   clk,
  input   reset_n,

  // inputs

  input [ 4-1 : 0 ] p_azmux_lo_val_i,
  input [ 4-1 : 0 ] p_azmux_hi_val_i,
  input [ 2-1 : 0 ] p_sw_pc_ctl_hi_val_i,
  input [24-1:0]    p_clk_count_precharge_i,


  input adc_measure_valid_i,

  // outputs.
  output reg adc_reset_no,  // rename _n_o. perhaps or trig. is even ok.

  output reg [ 2-1: 0]  sw_pc_ctl_o,
  output reg [ 4-1:0 ] azmux_o,
  output reg led0_o,
  // must be a register if driven synchronously.
  output reg [3-1: 0 ] status_o,        // bit 0 - hi/lo,  bit 1 - prim/w4,   bit 2. reserved.

  /*/ now a wire.  output wire [ 2-1:0]  monitor_o       // driven as wire/assign.
  // think it is ok to be a combinatory logic - wire output - although may slow things down.
  */
  output wire [ 8-1:0]  monitor_o

);

  reg [7-1:0]   state = 0 ;     // should expose in module, not sure.

  reg [31:0]    clk_count_down;           // clk_count for the current phase. using 31 bitss, gives faster timing spec.  v 24 bits. weird. ??? 36MHz v 32MHz



  assign monitor_o[0] = adc_reset_no;
  assign monitor_o[1] = adc_measure_valid_i;
  assign monitor_o[2 +: 6 ] = 0;

  // assign monitor_o[1] =  azmux_o == p_azmux_hi_val_i ; // `AZMUX_PCOUT;



  always @(posedge clk)
    begin

      // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;


      case (state)

        // precharge switch - protects the signal. from the charge-injection of the AZ switch.
        0:
          begin
            // having a state like, this may be useful for debuggin, because can put a pulse on the monitor_o.
            state <= 1;

            adc_reset_no    <= 0;


          end

        // switch pre-charge switch to boot to protect signal
        1:
          begin
            state           <= 15;
            clk_count_down  <= p_clk_count_precharge_i;
            sw_pc_ctl_o       <= 2'b00 ; // `SW_PC_BOOT;
          end
        15:
          if(clk_count_down == 0)
            state <= 2;


        ////////////////////////////
        // switch azmux_o from the LO to PCOUT (SIG/BOOT).    (signal is still currently protected by pc)  - the 'precharge phase' or settle phase
        // precharge phase.
        2:
            begin
              state           <= 25;
              clk_count_down  <= p_clk_count_precharge_i;  // normally pin s1
              azmux_o           <= p_azmux_hi_val_i;

              /*/ do we set the hi/lo status - at the start of adc measurement. or after complete/valid.
                  status should be established before the adc_valid .
                    - if after  - we risk not having correct status set, even though the adc valid interupt has been issued.
                    - if before - then get limited time (precharge time) to read the adc registers - before the status flag changes . / can read first.
                  ----
                  having the status set a few clk cycles after adc_valid is asserted is ok.
                  the data will be set correctly  during the time the the spi register is read.
              */
            end
        25:
          if(clk_count_down == 0)
            state <= 3;


        /////////////////////////
        // switch pc-switch from BOOT to signal. and tell adc to take measurement
        // also add small settle time. after switching the pc switch, for Vos between sig/boot to settle.
        3:
          begin
            state           <= 33;
            clk_count_down  <= p_clk_count_precharge_i;  // normally pin s1
            sw_pc_ctl_o     <= p_sw_pc_ctl_hi_val_i; // 2'b01 ; // SW_PC_SIGNAL;
          end

        33:
          if(clk_count_down == 0)
            begin
              state           <= 35;
              // adc start
              adc_reset_no <= 1;
            end

/*
        34:
          // wait for adc to ack trig, before advancing
          if( ! adc_measure_valid_i )
            begin
              adc_reset_no    <= 0;
              state             <= 35;
              led0_o            <= 1;

            end
*/

        35:
          // wait for adc to measure
          if( adc_measure_valid_i )
            begin
              state         <= 4;
              // set status for hi sample
              status_o    <= 3'b001; // we moved this.      // set status only after measure, to enable reg reading, during next measurement cycle.

              // JA added. put adc in reset again
              adc_reset_no <= 0;
            end

        //////////////////////////////

        // switch pre-charge switch back to boot to protect signal again
        // pause here can be shorter. if want.
        // but also nice to keep symmetrical
        4:
          begin
            state           <= 45;
            clk_count_down  <= p_clk_count_precharge_i; // time less important here
            sw_pc_ctl_o       <= 2'b00; // `SW_PC_BOOT;
          end

        45:
          if(clk_count_down == 0)
            state <= 5;

        /////////////////////////
        // switch az mux to lo.  pause and take lo measurement
        // but also nice to keep symmetrical
        5:
          begin
            state           <= 52;
            clk_count_down  <= p_clk_count_precharge_i; // time less important here
            azmux_o           <= p_azmux_lo_val_i;

          end

        52:
          if(clk_count_down == 0)
            begin
              state           <= 55;
              led0_o            <= 0;
              // adc start
              adc_reset_no <= 1;
            end

/*
        53:
          // wait for adc to ack trig, before advancing
          if( ! adc_measure_valid_i )
            begin
              adc_reset_no    <= 0;
              state             <= 55;
              led0_o            <= 0;
            end
*/
        55:
          // wait for adc to measure
          if(  adc_measure_valid_i )
            begin
              // restart sequence
              state <= 2;

              // set status for lo sample. set after measure to give time to read.
              status_o      <= 3'b000;

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





