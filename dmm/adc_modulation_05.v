

`default_nettype none

////////////////////////////


/*
  see,
    https://www.eevblog.com/forum/projects/multislope-design/75/
    https://patentimages.storage.googleapis.com/e2/ba/5a/ff3abe723b7230/US5200752.pdf
*/

// advantage of macros over localparam enum, is that they generate errors if not defined.
// disdvantage is that it is easy to forget the backtick


// change one-hot?.
`define STATE_DONE          0  // initial state

`define STATE_RESET_START    1
`define STATE_RESET          2
`define STATE_SIG_SETTLE_START 3
`define STATE_SIG_SETTLE    4
`define STATE_SIG_START     5
`define STATE_FIX_POS_START 6
`define STATE_FIX_POS       7
`define STATE_VAR_START     8
`define STATE_VAR           9
`define STATE_FIX_NEG_START 10
`define STATE_FIX_NEG       11
`define STATE_VAR2_START    12
`define STATE_VAR2          14
`define STATE_RUNDOWN_START 15
`define STATE_RUNDOWN       16

`define STATE_PRERUNDOWN    18
`define STATE_PRERUNDOWN_START 19

`define STATE_FAST_BELOW_START 20
`define STATE_FAST_BELOW    21

`define STATE_FAST_ABOVE_START 22
`define STATE_FAST_ABOVE    23



/*
  ref mux state.
  Note that this combines two 4053 switch..
*/

`define REFMUX_NONE        3'b000      // none - is required, because we turn off both pos-neg ref, to balance. switching.
`define REFMUX_POS         3'b001
`define REFMUX_NEG         3'b010
`define REFMUX_SLOW_POS    3'b011
`define REFMUX_RESET       3'b100


// could also define CMPR_ENABLE DIABLE and.   also also sigmux on, off.



module adc_modulation (


  input           clk,


  // wire. trigger/start a measurement cycle.
  input adc_measure_trig,

  // comparator input
  input           cmpr_val,

  // perhaps rename p_cc_aperture, p_cc_fix  etc.
  input [32-1:0]  p_clk_count_aperture,
  input [24-1:0]  p_clk_count_reset,      // useful if running stand-alone,
  input [24-1:0]  p_clk_count_fix,
  inout [24-1:0]  p_clk_count_var,
  input           p_use_slow_rundown,     // TODO prefix with p_. to indicate . an adc control parameter.
  input           p_use_fast_rundown,


  // outputs
  output reg adc_measure_valid,           // to indicate/assert completion, and valid measurement

  // now a wire
  output wire [ 6-1:0]  monitor,

  output reg [ 3-1:0]  refmux,            // reference current mux
  output reg sigmux,                      // sample/signal input mux


  // TODO need better name. hi = disable comparator and enable latch
  // corresponds to hardware.
  output reg      cmpr_latch_ctl,


  ///////////

  // copy of the registers, used to enable spi reading, in new measurement cycle.
  // long registers are 32/31 bit counts, eg. (1<<31)/20e6. == 107 seconds, for long integrations
  // having visibility over the reset clk count is also useful for check, and consistentcy.
  output reg [24-1:0] clk_count_refmux_reset_last,
  output reg [32-1:0] clk_count_refmux_neg_last,
  output reg [32-1:0] clk_count_refmux_pos_last,
  output reg [24-1:0] clk_count_refmux_rd_last,
  output reg [32-1:0] clk_count_mux_sig_last,      // names are correct. aperture is the control parameter,  and mux_sig_count is the current clk count for signal duration,



  // stats / behavior/transition counts
  // prefix with stat_
  output reg [24-1:0] stat_count_refmux_pos_up_last,
  output reg [24-1:0] stat_count_refmux_neg_up_last,
  output reg [24-1:0] stat_count_cmpr_cross_up_last,

  output reg [24-1:0] stat_count_var_up_last,
  output reg [24-1:0] stat_count_var_down_last,
  output reg [24-1:0] stat_count_fix_up_last,
  output reg [24-1:0] stat_count_fix_down_last,
  output reg [24-1:0] stat_count_flip_last
//   output reg [24-1:0] stat_clk_count_rundown_last, // change name. phase rundown.


);



  reg [5-1:0]   state;

  /*
     EXTR. could be useful to spi query the current state
    - could then determine that were updated during the reset period. and we don't have to call reset again.
  */

  // initial begin does seem to be supported.
  initial begin
    state           = `STATE_DONE ;   // 0

    // TODO remove.
    cmpr_latch_ctl  = 1; // disable comparator,

  end

  //////////////////////////////////////////////////////
  // counters and settings  ...

  reg [31:0]  clk_count_down;

  // modulation counts
  reg [24-1:0] clk_count_refmux_reset;
  reg [32-1:0] clk_count_refmux_neg;
  reg [32-1:0] clk_count_refmux_pos;
  reg [24-1:0] clk_count_refmux_rd;
  reg [32-1:0] clk_count_mux_sig ;      // should be the same as p_aperture.  eg. 5sec*20MHz=100m count. won't fit in 24 bit value. would need to split between read registers.


  // stats
  reg [24-1:0] stat_count_refmux_pos_up;
  reg [24-1:0] stat_count_refmux_neg_up;
  reg [24-1:0] stat_count_cmpr_cross_up;

  reg [24-1:0] stat_count_var_up;
  reg [24-1:0] stat_count_var_down;
  reg [24-1:0] stat_count_fix_up;
  reg [24-1:0] stat_count_fix_down;
  reg [24-1:0] stat_count_flip;



  /////////////////////////

  reg [2-1:0] cmpr_crossr;              // perhaps add _transition? or cmpr_

  wire cmpr_cross_up     = cmpr_crossr == 2'b10;
  wire cmpr_cross_down   = cmpr_crossr == 2'b01;
  wire cmpr_cross_any    = cmpr_cross_up || cmpr_cross_down ;



  reg [2-1:0] refmux_pos_cross;
  reg [2-1:0] refmux_neg_cross;

  wire refmux_pos_cross_up  = refmux_pos_cross == 2'b01;
  wire refmux_neg_cross_up  = refmux_neg_cross == 2'b01;



  // reg [ 4-1:0]  monitor_;
  assign monitor[0] = adc_measure_trig;
  assign monitor[1] = adc_measure_valid;


  assign monitor[2] = sigmux;
  assign monitor[3] = (state == `STATE_FAST_ABOVE_START);
  assign monitor[4] = (state == `STATE_FAST_BELOW_START);
  assign monitor[5] = (state == `STATE_RUNDOWN);


/*
  // assign monitor[ 2 +: 4]  = { sigmux, refmux };      // reference current, better name?
  assign monitor[ 2 +: 4]  = {

        (state == `STATE_RUNDOWN ),
        (state == `STATE_FAST_BELOW_START),
        (state == `STATE_FAST_ABOVE_START),
        sigmux
      };      // reference current, better name?
*/



  /*
      nov 12. 2023.
    we double flop.
    for meta-stability.  eg. to avoid read/use twice in same block, and can be evaluated differently.
    but perhaps review.
  */
  reg cmpr_val_last;

  always @(posedge clk)


    begin

      clk_count_down <= clk_count_down - 1;


      /* TODO nov 12. 2023.
        review why we do this. double flopping for stability on the clock edge.
        shouldn't matter?
      */
      // sample/bind comparator val once on clock edge. improves speed.
      cmpr_val_last <=  cmpr_val;


      cmpr_crossr               <= {cmpr_crossr[0], cmpr_val};

      // TODO change name ref_sw_pos_cross
      // instrumentation for switch transitions for both pos,neg (and both).
      refmux_pos_cross          <= { refmux_pos_cross[0], refmux[0] }; // old, new
      refmux_neg_cross          <= { refmux_neg_cross[0], refmux[1] };

      // TODO count_pos_trans or cross pos_  or just count_pos_trans
      // TODO must rename. actually represents count of each on switch transiton = count_ref_pos_on and count_ref_neg_on.
      if(refmux_pos_cross_up)
        stat_count_refmux_pos_up     <= stat_count_refmux_pos_up + 1;

      if(refmux_neg_cross_up)
        stat_count_refmux_neg_up     <= stat_count_refmux_neg_up + 1;

      if(cmpr_cross_up)
        stat_count_cmpr_cross_up     <= stat_count_cmpr_cross_up + 1;


      /*
        EI. use strategy of reading and counting the mux state values across the fsm state.
        avoids having to track for each state.
        ----
        it might also be more cycle accurate - given the phase transition setup, and comparator reads etc.
        but would need 32 bit values.
        - reduces spi overhead. if supported 32 byte reads.
        - reduces littering of count_var_up/count_var_down
        - reduces having to multiply out clk_count_var * count_var_up etc.
        - enables having non standar variable periods. eg. to reduce extra cycling to get to the other side.
        ------
            the way to evaluate is to use stderr(regression).
      */

      // synchronous behavior for all states

      case (refmux)

        `REFMUX_NEG:
            clk_count_refmux_neg <= clk_count_refmux_neg + 1;

        `REFMUX_POS:
            clk_count_refmux_pos <=  clk_count_refmux_pos + 1;

        `REFMUX_SLOW_POS:
            clk_count_refmux_rd <= clk_count_refmux_rd + 1;

        `REFMUX_NONE:
          ; // switches are turned off at start. and also at prerundown.
            // don't really need to count this

        `REFMUX_RESET:
            clk_count_refmux_reset <= clk_count_refmux_reset + 1;

      endcase


      if(sigmux )
        begin
          // while integrating the signal
          // increment aperture clk count
          clk_count_mux_sig <= clk_count_mux_sig + 1;

          // ======================================
          // aperture count termination condition.
          // changed oct 30, 2023..  IMPORTANT. DIFFERENCEs MAY AFFECT calibration calculation.
          // should be a count down
          // now revert.
          // NO. it may have been mcu roudinig. issue. reg_aperture. has the off-by-one. calculation
          // NO. we have it configured differently.
          // OK. it doesn't matter whether aperture runs - for one more extra clk cycle. or one less here.  nov 3. 2023.
          //    eg. clk termination condition doesn't matter.
          //    instead what matters is that the count is recorded in the same way as the counts for the reference currents.
          //    so mcu should use the returned count, rather than the aperture control parameter
          // =======================================

          // have we reached end of aperture
          if(clk_count_mux_sig >= p_clk_count_aperture)                  // original. slope-adc-3.
          // if(clk_count_mux_sig >= (p_clk_count_aperture - 1) )              // changed oct 30, 2023..  IMPORTANT. DIFFERENCEs MAY AFFECT calibration calculation.

            begin
              // turn off signal input
              sigmux  <= 0;

            end
        end


      case (state)


        `STATE_DONE:
          begin
            // default rest/park state

            // disable comparator,
            cmpr_latch_ctl <= 1;

            // indicate signal valid, to indicate interuptable status, to enable trigger
            adc_measure_valid <= 1;

            // turn off sigmux, and reset integrator
            sigmux            <= 0;
            refmux            <= `REFMUX_RESET;
          end


        `STATE_RESET_START:
          begin

            // de-assert valid measurement, at start of new measurement cycle
            adc_measure_valid <= 0;

            // reset vars, and transition to runup state
            state           <= `STATE_RESET;

            clk_count_refmux_reset <= 0;   // clear count to start

            clk_count_down   <= p_clk_count_reset;

            // JA
            sigmux          <= 0;
            refmux          <= `REFMUX_RESET;

            cmpr_latch_ctl          <= 1; // disable comparator, enable latch
          end



        `STATE_RESET:    // let integrator reset.
            if(clk_count_down == 0)
              state <= `STATE_SIG_START;



        // turn on signal integration, turn off reset, begin two phase runup
        `STATE_SIG_START:
          begin
            state             <= `STATE_FIX_POS_START;

            // turn on signal input, to start signal integration
            sigmux            <= 1;
            refmux            <= `REFMUX_NONE; // turn off reset.     // TODO think this is correct. we don't want to increment signal count, while refmux is held in reset.

            // clear counts
            clk_count_refmux_neg  <= 0;
            clk_count_refmux_pos  <= 0;
            clk_count_refmux_rd   <= 0;
            clk_count_mux_sig     <= 0;

            /////////////////////////////
            // perhaps should do at reset/ done state.
            // clear the counts
            stat_count_var_up      <= 0;
            stat_count_var_down    <= 0;
            stat_count_fix_up      <= 0;
            stat_count_fix_down    <= 0;
            stat_count_refmux_pos_up    <= 0;
            stat_count_refmux_neg_up  <= 0;
            stat_count_flip        <= 0;
            stat_count_cmpr_cross_up <= 0;
          end


        // cycle +-ref currents, with/or without signal
        `STATE_FIX_POS_START:
          begin
            state             <= `STATE_FIX_POS;
            clk_count_down    <= p_clk_count_fix;

            stat_count_fix_down    <= stat_count_fix_down + 1;
            refmux            <= `REFMUX_POS; // initial direction

            cmpr_latch_ctl  <= 0; // enable comparator, // JA correct. 0 means it is transparent.
          end

        `STATE_FIX_POS:
          if(clk_count_down == 0)
            state <= `STATE_VAR_START;



        // variable direction
        `STATE_VAR_START:
          begin
            state             <= `STATE_VAR;
            clk_count_down    <= p_clk_count_var;

            if( cmpr_val_last)   // test below the zero-cross
              begin
                refmux        <= `REFMUX_NEG;  // add negative ref. to drive up.
                stat_count_var_up  <= stat_count_var_up + 1;
              end
            else
              begin
                refmux        <= `REFMUX_POS;
                stat_count_var_down <= stat_count_var_down + 1;
              end
          end



        `STATE_VAR:
          if(clk_count_down == 0)
            state <= `STATE_FIX_NEG_START;


        `STATE_FIX_NEG_START:
          begin
            state         <= `STATE_FIX_NEG;
            clk_count_down    <= p_clk_count_fix;

            stat_count_fix_up  <= stat_count_fix_up + 1;
            refmux        <= `REFMUX_NEG;
          end


        `STATE_FIX_NEG:
          // TODO add switch here for 3 phase modulation variation.
          if(clk_count_down == 0)
            state <= `STATE_VAR2_START;


        // variable direction
        `STATE_VAR2_START:
          ///////////
          // EXTR.  actually since we stopped injecting signal - it doesn't matter how many cycles we use to get above zero-cross.
          // and it will happen reasonably quickly. because of the bias.
          // so just keep running complete 4 phase cycles until we get a cross. rather than force positive vars.
          //////////
          begin
            state             <= `STATE_VAR2;
            clk_count_down    <= p_clk_count_var;

            if( cmpr_val_last) // below zero-cross
              begin
                refmux        <= `REFMUX_NEG;
                stat_count_var_up  <= stat_count_var_up + 1;
              end
            else
              begin
                refmux        <= `REFMUX_POS;
                stat_count_var_down <= stat_count_var_down + 1;
              end
          end

        /*
          E. IMPORTANT
          - solution to jump immediately to pre/rundown. without extra cycling.
            is just to keep adding up fix periods until above cross.

        */
        `STATE_VAR2:
          if(clk_count_down == 0)
            begin
              // signal integration finished.
              if( !sigmux)

                if(p_use_fast_rundown)
                  begin
                    if(  cmpr_val_last) // below cross
                      state <= `STATE_FAST_BELOW_START;
                    else                      // above cross
                      state <= `STATE_FAST_ABOVE_START;
                  end
                else
                  begin
                    // above cross and last var was up phase
                    if( refmux  == `REFMUX_NEG && ! cmpr_val_last)
                      state <= `STATE_PRERUNDOWN_START;
                    else
                      // keep cycling
                      state <= `STATE_FIX_POS_START;

                      stat_count_flip <= stat_count_flip + 1;
                  end

              // signal integration not finished
              else
                  // do another cycle
                  state <= `STATE_FIX_POS_START;
            end

        //////////////////////////////////////////////
        // fast rundown.

        /*
        EXTR. cmpr hysteresis. affects setup for rundown.
        means we don't have to pad small extra clk count,
        to guarantee, we don't miss a crossing.
        */
        // we are somewhere above zero,
        // advance until below zero cross.
        `STATE_FAST_ABOVE_START:
          begin
            refmux          <= `REFMUX_POS;

            if( cmpr_val_last)                  // below zero-cross. EXTR. note not a comparator transition test. instead an actual value .
              state   <= `STATE_FAST_BELOW_START;     // advance to below_start.
          end


        /*
          cmpr hystersis means more clk cycles, than  would need for exact cross.
          also slope-amp will determine how many clk cycles needed to get across positive hysterisis.

        */
        // advance until above zero-cross.
        `STATE_FAST_BELOW_START:
           begin
            refmux    <= `REFMUX_NEG;

             if( ! cmpr_val_last) // above zero-cross
              // state   <= `STATE_PRERUNDOWN_START;   // go to pre-rundown
              state         <= `STATE_RUNDOWN_START; // goto rundown.
            end


/*
      TODO nov 12. 2023.
        this code equalized switch transitions. by turning off both pos and neg ref currents, before switching on both together.
        but it's not clear if it is still needed.
        with the changes to the prerundown.

        ////////////////////////////////////////////
        // the end of signal integration. is different to the end of the 4 phase cycle.
        // we want a gpio pin. to hit on pre-rundown.

        `STATE_PRERUNDOWN_START:
           begin
            state     <= `STATE_PRERUNDOWN;
            clk_count_down    <= p_clk_count_fix;

                // we don't care about landing above the zero-cross. in 4 phase we care about ending on a downward var.
                // thatway we can add a up transition.  before doing the downward transition (for slow) rundown.
                // to balance the up/down transitions.
                // the upward phase - then needs to be enough to push over the zero-cross.  but that is secondary.
                ----------

            refmux    <= `REFMUX_NONE;
          end

        // It has to be MUX_NONE

        `STATE_PRERUNDOWN:
          // Should drive above the cross.
          // EXTR. this can just keep driving up, without transitions, and testing until hit the zero cross.
          // No. i think it would actually depend on whether the last /
          // then we get
          if(clk_count_down == 0)
            state <= `STATE_RUNDOWN_START;
*/



        `STATE_RUNDOWN_START:
          begin
            state         <= `STATE_RUNDOWN;

            /*
              IMPORTANT. we are not counting a possible switch transition here.
              Bug?
            */
            if( p_use_slow_rundown )
              // turn on both references - to create +ve bias, to drive integrator down.
              refmux      <= `REFMUX_SLOW_POS;
            else
              // fast rundown
              refmux      <= `REFMUX_POS;
          end


        `STATE_RUNDOWN:
          begin
            // TODO change to cmpr_val test.
            // zero-cross to finish. should probably change to use last_comparator
            if(cmpr_cross_any )
              begin

                cmpr_latch_ctl          <= 1; // disable comparator,

                // signal valid measurement.
                adc_measure_valid <= 1;

                // next transition
                state                   <= `STATE_DONE;

                // turn off sigmux, and reset integrator
                sigmux                  <= 0;
                refmux                  <= `REFMUX_RESET;

                // counts
                clk_count_refmux_reset_last <= clk_count_refmux_reset;    // this doesn't work. reports 0.
                clk_count_refmux_neg_last  <= clk_count_refmux_neg;
                clk_count_refmux_pos_last  <= clk_count_refmux_pos;
                clk_count_refmux_rd_last   <= clk_count_refmux_rd;
                clk_count_mux_sig_last    <= clk_count_mux_sig;                  // aperture. is the ctrl parameter for signal introduced..
                                                                            // TODO. rename clk_count_mux_sig.

                // stats
                stat_count_refmux_pos_up_last   <= stat_count_refmux_pos_up ; // OK. this works.
                stat_count_refmux_neg_up_last   <= stat_count_refmux_neg_up ;
                stat_count_cmpr_cross_up_last <= stat_count_cmpr_cross_up ;

                stat_count_var_up_last       <= stat_count_var_up;
                stat_count_var_down_last     <= stat_count_var_down;
                stat_count_fix_up_last       <= stat_count_fix_up;
                stat_count_fix_down_last     <= stat_count_fix_down;
                stat_count_flip_last         <= stat_count_flip;
                // stat_clk_count_rundown_last  <= clk_count;                           // why do we record this

              end
          end



      endcase


        // adc is always interruptable/ can be triggered to start at any time.
        if(adc_measure_trig == 1)
          begin

            state <= `STATE_RESET_START;

          end

    end


endmodule


