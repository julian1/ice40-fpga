
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





`define SEQ_AZMUX_SLICE       0 +: 4
`define SEQ_PC_SLICE          4 +: 2
`define SEQ_NEXT_IDX_SLICE    6 +: 3





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


  input [ 32-1:0] p_seq0_i,
  input [ 32-1:0] p_seq1_i,
  input [ 32-1:0] p_seq2_i,
  input [ 32-1:0] p_seq3_i,



  // adc inputs

  input             adc_conversion_valid_i,


  /////////////////////////
  // adc outputs


  /* expose in module, not sure.
    for non-intrusive observation
    consider adding _o .  but it is really an internal state
  */
  output reg [7-1:0]  state,

  output reg          adc_reset_no,              // hold adc in reset.

  output reg          adc_conversion_start_o,      // one-clock cycle control

  //////////////
  // control outputs

  output reg [ 2-1:0]  pc_sw_o,
  output reg [ 4-1:0]  azmux_o,



  ////////////////

  output reg  [3-1: 0] sample_idx_o,



  /*
    TODO bad name.
    rename    p_term.  or p_seq_elt;  etc.
    it is not a parameter
  */
  output reg   [ 32-1: 0]      seq_elt
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

              // sample_first_o  <= 1;

              /* during reset - hold the precharge switches lo. to emit BOOT. and protect signal. both cahnnels
                azmux state should probably also be defined.  can use the first value.
              */
              pc_sw_o       <= 2'b00;

              /* TODO review.  this may not be a lo.
                we are using the first element here. which may not be
              */
              azmux_o       <= p_seq0_i[ `SEQ_AZMUX_SLICE];



            end


          `STATE_TRIG_DELAY:
            if(clk_count_down == 0)
              state         <= `STATE_PC_PROTECT_START;

          ////////////////////////////////////////////


          // switch pre-charge switch to boot to protect signal, and pause.
          `STATE_PC_PROTECT_START:
            begin


              case( sample_idx_o)
                0: seq_elt  <= p_seq0_i;
                1: seq_elt  <= p_seq1_i;
                2: seq_elt  <= p_seq2_i;
                3: seq_elt  <= p_seq3_i;
              endcase


              state           <= `STATE_PC_PROTECT;
              clk_count_down  <= p_clk_count_precharge_i;

              // keep the pc_sw lo if coming from reset_start/trig_delay
              // switch to pc_sw lo if coming from wait_adc
              pc_sw_o         <= 2'b00;

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
              azmux_o         <= seq_elt[ `SEQ_AZMUX_SLICE ];
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
              pc_sw_o         <= seq_elt[ `SEQ_PC_SLICE ];
            end


          `STATE_PC_SAMPLE:
            if(clk_count_down == 0)
              begin

                state                   <= `STATE_WAIT_ADC;
                // adc start
                adc_reset_no            <= 1'b1;

                adc_conversion_start_o  <= 1'b1;
              end



          `STATE_WAIT_ADC:
            // wait for adc to measure
            if( adc_conversion_valid_i)
              begin

                // set up next state
                state         <= `STATE_PC_PROTECT_START;

                // ok. works
                sample_idx_o    <= seq_elt[ `SEQ_NEXT_IDX_SLICE];


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



      else if ( mode_i == 1)
        begin

          // instead of passing and using reg_direct here,
          // just load and hold seq0

          pc_sw_o     <= p_seq0_i[ `SEQ_PC_SLICE];
          azmux_o     <= p_seq0_i[ `SEQ_AZMUX_SLICE ];

        end

      else if ( mode_i == 2)
        begin

          // the same - but should run the adc as well.
          // this kind of needs an NOAZ mode with a single LO first... to watch.

          pc_sw_o     <= p_seq0_i[ `SEQ_PC_SLICE];
          azmux_o     <= p_seq0_i[ `SEQ_AZMUX_SLICE];

        end




endmodule





