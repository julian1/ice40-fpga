
/*

  supervisor.

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

  input [ 3-1: 0 ]  mode_i,       // cr mode

  // control inputs
  input [32-1:0]    p_clk_count_trig_delay_i,
  input [24-1:0]    p_clk_count_precharge_i,

  input [ 3-1: 0 ]  p_seq_n_i,    // need at least 3 bits to encode 4.
  input [ 6-1 : 0 ] p_seq0_i,
  input [ 6-1 : 0 ] p_seq1_i,
  input [ 6-1 : 0 ] p_seq2_i,
  input [ 6-1 : 0 ] p_seq3_i,

  input             p_noaz_i,


  // adc inputs

  input             adc_conversion_valid_i,


  /////////////////////////
  // adc outputs


  /* expose in module, not sure.
    for non-intrusive observation
    consider adding _o .  but it is really an internal state
  */
  output reg [7-1:0]    state,



  output reg        adc_reset_no,              // hold adc in reset.

  output reg        adc_conversion_start_o,      // one-clock cycle control

  //////////////
  // control outputs

  output reg [ 2-1:0]  pc_sw_o,
  output reg [ 4-1:0]  azmux_o,



  ////////////////

  output reg  [3-1: 0] sample_idx_o,

  /*
    first sample after trigger assert
    deasserted after sequence cycle complete
    better than count - which is overflow and seeing 0 again.
    ----------

    EXTR. OK. this will not work - with idea of modes.
    because it is a flag to change the nplc.
  */
  output reg           sample_first_o,



);



  // clk_count for the current phase. 31 bitss, gives faster timing spec.  v 24 bits. weird. ??? 36MHz v 32MHz
  reg [31:0]    clk_count_down;


  initial begin

      // STATE_RESET_START
      state  = 0;

  end


  /*  extr.
      separate the state machine. for the different modes
      and then we just assign the correct outputs depending on the state mode.
      - this may be an easier way to implement the patterns  - instead of setting different starter states
      -----
      no-   because would have clock propagation delay.
  */


  always @(posedge clk)

    if( mode_i == 0)
      begin

        // always decrement clk for the current phase
        clk_count_down          <= clk_count_down - 1;

        adc_conversion_start_o  <= 1'b0;

        case (state)

          // reset state
          `STATE_RESET_START:
            begin

              state           <= `STATE_TRIG_DELAY;
              clk_count_down  <= p_clk_count_trig_delay_i;

              // hold adc in reset also
              adc_reset_no    <= 0;

              sample_idx_o    <= 0;

              sample_first_o  <= 1;

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


              case( sample_idx_o)
                0: begin azmux_o   <= p_seq0_i[ 0 +: 4 ]; end
                1: begin azmux_o   <= p_seq1_i[ 0 +: 4]; end
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

              case(sample_idx_o)
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
                adc_reset_no  <= 1'b1;

                adc_conversion_start_o  <= 1'b1;
              end



          `STATE_WAIT_ADC:
            // wait for adc to measure
            if( adc_conversion_valid_i )
              begin

                // set up next state
                state         <= `STATE_PC_PROTECT_START;


                /*
                  avoid modulo
                  https://stackoverflow.com/questions/47425729/verilog-modulus-operator-for-wrapping-around-a-range
                  needs to be >= in case sample_n is reduced in write.
                */
                if( !p_noaz_i)

                  if( sample_idx_o < p_seq_n_i - 1)
                    sample_idx_o  <= sample_idx_o + 1;
                  else
                    begin
                      sample_idx_o    <=  0;

                      sample_first_o  <= 0;
                    end

                else
                  // FIXME
                  sample_idx_o <= 1;

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

      end   // end mode == 0


endmodule





