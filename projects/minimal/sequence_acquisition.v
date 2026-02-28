
/*
   keep the precharge time the same, when taking a LO - to keep simpler / symmetry and to be more generic.

  remember
    - use idx to communicate back to the mcu the current sample in the sequence via the status register.
    - lo idx is always 0 in AZ. and 2 in ratiometric.
    - could also return the azmux and pc state used for the sample


*/


// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


// todo change name common. or macros. actually defines is ok.etc
`include "defines.v"


// should use one-hot?
`define STATE_RESET_START       0
`define STATE_TRIG_DELAY        1

`define STATE_PC_PROTECT_START  2
`define STATE_PC_PROTECT        3


`define STATE_SIGNAL_START      4
`define STATE_SIGNAL            5


`define STATE_PC_SAMPLE_START   6
`define STATE_PC_SAMPLE         7


`define STATE_WAIT_ADC          8


// rename sample_sequence_acquisition
// or sample_acquisition_sequence

module sequence_acquisition (

  // remember hi mux is not manipulated, or given to this module.
  // inistead the hi signal is seleced by the AZ mux, via the pre-charge switch

  input   clk,
  input   reset_n,

  // inputs
  input [32-1:0]    p_clk_count_trig_delay_i,
  input [24-1:0]    p_clk_count_precharge_i,

  input [ 3-1: 0 ]  p_seq_n_i,    // need at least 3 bits to encode 4.
  input [ 6-1 : 0 ] p_seq0_i,
  input [ 6-1 : 0 ] p_seq1_i,
  input [ 6-1 : 0 ] p_seq2_i,
  input [ 6-1 : 0 ] p_seq3_i,

  input             p_noaz,


  input             adc_measure_valid_i,

  // outputs.
  output reg        adc_reset_no,              // control the adc.  rename _n_o. perhaps or trig. is even ok.

  output reg [ 2-1: 0]  pc_sw_o,
  output reg [ 4-1:0 ]  azmux_o,



  output wire [4-1:0]   leds_o,

  /*/ now a wire.  output wire [ 2-1:0]  monitor_o       // driven as wire/assign.
  // think it is ok to be a combinatory logic - wire output - although may slow things down.
  */
  output wire [ 8-1:0] monitor_o,


  ////////////////

  output reg  [3-1: 0] sample_idx ,

  // is it the first reading after trigger assert
  output reg           first ,

);



  // should expose in module, not sure.
  reg [7-1:0]   state = 0 ;


  // clk_count for the current phase. 31 bitss, gives faster timing spec.  v 24 bits. weird. ??? 36MHz v 32MHz
  reg [31:0]    clk_count_down;






  assign monitor_o[0] = (azmux_o == `S3);   // (count == 0 ) etc.
  assign monitor_o[1] = (azmux_o == `S7);
  assign monitor_o[2] = (azmux_o == `S1);
  assign monitor_o[3] = (azmux_o == `S8);

  assign monitor_o[4] = pc_sw_o[0 ] ;
  assign monitor_o[5] = pc_sw_o[1 ] ;

  assign monitor_o[6] = adc_reset_no;
  assign monitor_o[7] = adc_measure_valid_i;


  assign leds_o[0] = (sample_idx == 0);
  assign leds_o[1] = (sample_idx == 1);
  assign leds_o[2] = (sample_idx == 2);
  assign leds_o[3] = (sample_idx == 3);

  always @(posedge clk)
    begin

      // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;


      case (state)

        // reset state
        `STATE_RESET_START:
          begin
            // having a state like, this may be useful for debuggin, because can put a pulse on the monitor_o.
            state         <= `STATE_TRIG_DELAY;
            clk_count_down <= p_clk_count_trig_delay_i;

            // hold adc in reset also
            adc_reset_no  <= 0;

            sample_idx    <= 0;

            first         <= 1;


            /* during reset - hold the precharge switches lo. to emit BOOT. and protect signal. both cahnnels
            // azmux state should probably also be defined.  can use the first value.
            */
            pc_sw_o       <= 2'b00;
            azmux_o       <= p_seq0_i[ 0 +: 4 ];
          end


        `STATE_TRIG_DELAY:
          if(clk_count_down == 0)
            state         <= `STATE_PC_PROTECT_START;



        // switch pre-charge switch to boot to protect signal, and pause.
        `STATE_PC_PROTECT_START:
          begin
            state         <= `STATE_PC_PROTECT;
            clk_count_down <= p_clk_count_precharge_i;

            // keep the pc_sw lo if coming from reset_start/trig_delay
            // switch to pc_sw lo if coming from wait_adc
            pc_sw_o       <= 2'b00;

          end

        `STATE_PC_PROTECT:
          if(clk_count_down == 0)
            state <= `STATE_SIGNAL_START;




        ////////////////////////////
        // switch azmux_o to the signal of interest, which may be a low. and pause
        // precharge phase.
        `STATE_SIGNAL_START:
          begin
            state           <= `STATE_SIGNAL;
            clk_count_down  <= p_clk_count_precharge_i;  // normally pin s1

            case( sample_idx)
              0: azmux_o   <= p_seq0_i[ 0 +: 4 ];
              1: azmux_o   <= p_seq1_i[ 0 +: 4];
              2: azmux_o   <= p_seq2_i[ 0 +: 4 ];
              3: azmux_o   <= p_seq3_i[ 0 +: 4];
            endcase
          end

        `STATE_SIGNAL:
          if(clk_count_down == 0)
            state <= `STATE_PC_SAMPLE_START;



        /////////////////////////
        // switch pc-switch from BOOT to the signal input if defined (which may be a ground), and pause.
        // if we are sampling a ground, and pc_val = 0, then this does nothing.
        // and we could skip it, but probably not unreasonable to keep timing the same.
        `STATE_PC_SAMPLE_START:
          begin
            state           <= `STATE_PC_SAMPLE;
            clk_count_down  <= p_clk_count_precharge_i;  // normally pin s1

            case(sample_idx)
              0: pc_sw_o <= p_seq0_i[4 +: 2];
              1: pc_sw_o <= p_seq1_i[4 +: 2];
              2: pc_sw_o <= p_seq2_i[4 +: 2];
              3: pc_sw_o <= p_seq3_i[4 +: 2];
            endcase
          end

        `STATE_PC_SAMPLE:
          if(clk_count_down == 0)
            begin
              state         <= `STATE_WAIT_ADC;
              // adc start
              adc_reset_no  <= 1;
            end



        `STATE_WAIT_ADC:
          // wait for adc to measure
          if( adc_measure_valid_i )
            begin

              // set up next state
              state         <= `STATE_PC_PROTECT_START;

              first         <= 0;

              /*
                avoid modulo
                https://stackoverflow.com/questions/47425729/verilog-modulus-operator-for-wrapping-around-a-range
                needs to be >= in case sample_n is reduced in write.
              */
              if(!p_noaz)
                sample_idx <= (sample_idx >= p_seq_n_i - 1)
                                ? 0
                                : sample_idx + 1;
              else
                sample_idx <= 1;

              // put adc in reset again
              adc_reset_no <= 0;
            end

      endcase



      // override all states -
      // if reset_n enabled, then don't advance out-of reset state.
      if(reset_n == 0)      // in reset
        begin

            state <= `STATE_RESET_START;
        end



    end
endmodule





