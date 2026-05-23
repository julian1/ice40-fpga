/*
  - the alternative way to manage this could be a rv32 softcore
  with the sequences constructed based on the channel,noaz,oob control flags.

*/
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


// use one-hot?
`define STATE_RESET_START       0
`define STATE_TRIG_DELAY        1

// rename seq-elt-fetch
`define STATE_INSN_FETCH        2
// `define STATE_INSN_DECODE       3


`define STATE_PC_PROTECT_START  4
`define STATE_PC_PROTECT        5


`define STATE_SWITCH_START      6
`define STATE_SWITCH            7


`define STATE_PC_SAMPLE_START   8
`define STATE_PC_SAMPLE         9


`define STATE_ADC_START         11
`define STATE_ADC_WAIT          12






/*
  consider rename
  or just sequencer
  or sample_sequencer or acquisition_sequencer
*/

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



  /////////////////////////
  // adc input

  /* adc inputs - one clock control.
    consider rename to _done.  because not a _ready,_valid hanshake.
  */
  input             adc_conversion_valid_i,


  /////////////////////////
  // adc outputs


  output reg          adc_reset_no,               // hold adc in reset.

  output reg          adc_conversion_start_o,    // one-clock cycle control

  //////////////
  // control outputs

  output reg [ 2-1:0]  pc_sw_o,
  output reg [ 4-1:0]  azmux_o,




  ////////////////


  /* expose state in module port-list/arguments - for non-intrusive fsm actions
    do not add _o suffix, but it is more properly considered to be internal state
  */
  output reg [7-1:0]  state,



  output reg  [3-1: 0]  sample_idx,

  output reg          sample_first,


  /*
    TODO bad name.
    rename    p_term.  or p_seq_elt;  etc.
    or insn   or seq_insn
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

              sample_idx    <= 0;

              sample_first  <= 1;

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
              state         <= `STATE_INSN_FETCH;



          ////////////////////////////////////////////

          // get the next sequence state
          `STATE_INSN_FETCH:
            begin

              // do in block..  so fields are available to subsequent bocks
              case( sample_idx)
                0: seq_elt  <= p_seq0_i;
                1: seq_elt  <= p_seq1_i;
                2: seq_elt  <= p_seq2_i;
                3: seq_elt  <= p_seq3_i;
              endcase

              state         <= `STATE_PC_PROTECT_START;
            end



/*
          `STATE_INSN_DECODE:   // and execute
            begin

              if( seq_elt[ `SEQ_CODE_SLICE ] == `INSN_NORMAL)
                state         <= `STATE_PC_PROTECT_START;

              else if( seq_elt[ `SEQ_CODE_SLICE ] == `INSN_JMP)
                begin

                  sample_idx    <= seq_elt[ `OP_NEXT_IDX_SLICE];
                  state         <= `STATE_INSN_FETCH;
                end

            end
*/



          // switch protect phase - switch pre-charge to lo/input boot/buffer to protect signal, and pause
          `STATE_PC_PROTECT_START:
            begin

              state           <= `STATE_PC_PROTECT;
              clk_count_down  <= p_clk_count_precharge_i;

              // pc_sw_o         <= 2'b00;
              // use variable. to support disabling for high-impedance/electrometer mode.
              // and testing input leakage.
              pc_sw_o         <= seq_elt[ `SEQ_PC_PROTECT_SLICE ];
            end

          `STATE_PC_PROTECT:
            if(clk_count_down == 0)
              state <= `STATE_SWITCH_START;




          ////////////////////////////
          // switch azmux_o to the signal of interest, which may be a low. and pause
          // precharge phase.
          `STATE_SWITCH_START:
            begin

              state           <= `STATE_SWITCH;
              clk_count_down  <= p_clk_count_precharge_i;  // normally pin s1
              azmux_o         <= seq_elt[ `SEQ_AZMUX_SLICE ];
            end

          `STATE_SWITCH:
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

              pc_sw_o         <= seq_elt[ `SEQ_PC_SAMPLE_SLICE ];
            end


          `STATE_PC_SAMPLE:
            if(clk_count_down == 0)
              state           <= `STATE_ADC_START;


          `STATE_ADC_START:
              begin

                state                   <= `STATE_ADC_WAIT;
                // adc start
                adc_reset_no            <= 1'b1;

                adc_conversion_start_o  <= 1'b1;
              end


          `STATE_ADC_WAIT:
            // wait for adc to measure
            if( adc_conversion_valid_i)
              begin

                // set up next state
                state           <= `STATE_INSN_FETCH;

                sample_idx      <= seq_elt[ `SEQ_NEXT_IDX_SLICE];

                // clear sample first flag
                sample_first    <= 1'b0;

                // put adc back in reset
                adc_reset_no    <= 0;
              end

        endcase

        // override all states -
        // if reset_n enabled, then don't advance out-of reset state.
        if(reset_n == 0)      // in reset
          begin

              state <= `STATE_RESET_START;
          end

      end   // end mode == 0

      /*
        - if encode the protection pre-charge state for use during azmux change in the sequence element
            then we can hold pc and azmux constant through the switching sequence for the adc - and to do leakage test.
            ---------
            - similarly can keep off in both stages - for the high-Z/ electrometer mode.  note noaz mode will work well for this.

            - consider encoding leds - lower two leds to the azmux_o channell hi/lo.  and upper two leds if sw_pc_o  was active.
                - do this in top.v
      */
      /*

        need modes.
          - for charge-injection - switch pre-charge switch normally. with adc (using an initial zero/noaz).  with input high-z.
                                    - think just normal noaz operation, with pc switching, . with input held high-z?

          - leakage               - similar. but without pre-charge switching.  adc runs noaz.
                                    - may be normal noaz operation, with no pc switching. which will need a different mode.

          - remember. can control azmux to connect to gnd (a400-1, S6). to discharge input capacitance - using a sequence-elt.

      */

      else if ( mode_i == 1)
        begin

          // instead of passing and using reg_direct here,
          // just load and hold seq0

          /*
              EXTR.  can load and interpret the insn/p_seq0_i  any way we want.
              and use a c-union for the data structure on the mcu side.

              eg. to include direct timing information - for aperture,var,fix. or 10 second wait etc.
              can right-shift counts to compress them in the 32 bit structure..
              --
              considder put next_idx.  first.  and all subsequent fields can be interpreted as union.
              or just have separate op code for a idx jump
          */

          pc_sw_o     <= p_seq0_i[ `SEQ_PC_SAMPLE_SLICE];
          azmux_o     <= p_seq0_i[ `SEQ_AZMUX_SLICE ];

        end




endmodule





